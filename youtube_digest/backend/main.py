import os
import re
import datetime
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Query, Header
from youtube_transcript_api import YouTubeTranscriptApi, TranscriptsDisabled, NoTranscriptFound
from googleapiclient.discovery import build
import openai
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="YouTube Digest Backend")

# Configure OpenAI
client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
yt_transcript_api = YouTubeTranscriptApi()

YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")

class VideoSummary(BaseModel):
    video_id: str
    title: str
    channel_name: str
    published_at: str
    summary: str
    thumbnail_url: str

class ChannelValidation(BaseModel):
    is_valid: bool
    channel_name: Optional[str] = None
    channel_thumbnail: Optional[str] = None
    error: Optional[str] = None

def get_channel_id(url: str) -> str:
    # Basic regex or API call to get channel ID from various URL formats
    if "channel/" in url:
        return url.split("channel/")[1].split("/")[0]
    # For handles (@name) or user/name, we need the API
    return url

def get_latest_videos(channel_id: str, days: int = 1, api_key: str = None) -> List[dict]:
    yt_key = api_key or YOUTUBE_API_KEY
    if not yt_key:
        return []
    
    youtube = build("youtube", "v3", developerKey=yt_key)
    
    # First, get the 'uploads' playlist ID for the channel
    # This works if channel_id is already the ID. If it's a handle, we need to search first.
    try:
        if "@" in channel_id or ("/c/" in channel_id) or ("/user/" in channel_id):
            # Simplified: just use search if it's not a direct ID
            search_response = youtube.search().list(
                q=channel_id,
                type="channel",
                part="id",
                maxResults=1
            ).execute()
            if not search_response["items"]:
                return []
            channel_id = search_response["items"][0]["id"]["channelId"]

        channel_response = youtube.channels().list(
            id=channel_id,
            part="contentDetails,snippet"
        ).execute()
        
        if not channel_response["items"]:
            return []
            
        uploads_playlist_id = channel_response["items"][0]["contentDetails"]["relatedPlaylists"]["uploads"]
        channel_name = channel_response["items"][0]["snippet"]["title"]

        # Get videos from uploads playlist
        playlist_response = youtube.playlistItems().list(
            playlistId=uploads_playlist_id,
            part="snippet,contentDetails",
            maxResults=10
        ).execute()

        latest_videos = []
        for item in playlist_response.get("items", []):
            published_at_str = item["snippet"]["publishedAt"]
            latest_videos.append({
                "video_id": item["contentDetails"]["videoId"],
                "title": item["snippet"]["title"],
                "published_at": published_at_str,
                "channel_name": channel_name,
                "thumbnail_url": item["snippet"]["thumbnails"]["high"]["url"]
            })
            break # ONLY TAKE THE LATEST ONE
        
        return latest_videos
    except Exception as e:
        print(f"Error fetching videos for {channel_id}: {e}")
        return []

def get_transcript(video_id: str) -> str:
    print(f"DEBUG: Attempting to fetch transcript for VIDEO_ID: {video_id}")
    try:
        # Try fetching standard transcripts
        transcript_list = yt_transcript_api.list(video_id)
        
        # Look for any English transcript (manual or generated)
        try:
            transcript = transcript_list.find_transcript(['en'])
            print(f"DEBUG: Found English transcript (manual or auto) for {video_id}.")
            return " ".join([t.text for t in transcript.fetch()])
        except:
            # Fallback: just take the first one available
            print(f"DEBUG: No English transcript. Trying the first available transcript...")
            first_transcript = next(iter(transcript_list))
            return " ".join([t.text for t in first_transcript.fetch()])
                
    except (TranscriptsDisabled, NoTranscriptFound):
        print(f"DEBUG: Transcripts disabled or not found for {video_id}.")
        return ""
    except Exception as e:
        print(f"DEBUG: Unexpected error fetching transcript for {video_id}: {type(e).__name__}: {e}")
        return ""

def summarize_text(text: str, custom_key: Optional[str] = None) -> str:
    if not text:
        return "No transcript available."
    
    # Use custom key if provided, otherwise the global client uses default key
    temp_client = client
    if custom_key:
        temp_client = openai.OpenAI(api_key=custom_key)
    
    prompt = f"""
    Please provide a concise, structured summary of the following YouTube video transcript.
    Use bullet points for key takeaways. Keep it clear and easy to read.
    Keep the total length under 200 words.
    
    Transcript:
    {text[:10000]} # Limit transcript length for safety
    """
    
    try:
        response = temp_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that summarizes YouTube video transcripts."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=300
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"Error summarizing with OpenAI: {e}")
        return "Summary generation failed."

@app.get("/digest", response_model=List[VideoSummary])
async def get_digest(
    channels: List[str] = Query(...),
    x_openai_key: Optional[str] = Header(None),
    x_youtube_key: Optional[str] = Header(None)
):
    all_summaries = []
    yt_key = x_youtube_key or YOUTUBE_API_KEY
    
    for channel_url in channels:
        videos = get_latest_videos(channel_url, api_key=yt_key)
        for v in videos:
            transcript = get_transcript(v["video_id"])
            summary = summarize_text(transcript, custom_key=x_openai_key)
            all_summaries.append(VideoSummary(
                video_id=v["video_id"],
                title=v["title"],
                channel_name=v["channel_name"],
                published_at=v["published_at"],
                summary=summary,
                thumbnail_url=v["thumbnail_url"]
            ))
            
    return all_summaries

@app.get("/validate-channel", response_model=ChannelValidation)
async def validate_channel(url: str, x_youtube_key: Optional[str] = Header(None)):
    yt_key = x_youtube_key or YOUTUBE_API_KEY
    if not yt_key:
        return ChannelValidation(is_valid=False, error="YouTube API Key not configured")
    
    youtube = build("youtube", "v3", developerKey=yt_key)
    
    try:
        # 1. Try to detect a handle (starts with @ or contains youtube.com/@)
        handle = None
        if "@" in url:
            handle = "@" + url.split("@")[-1].split("/")[0].split("?")[0]
        elif not url.startswith("http") and not url.startswith("UC"):
            # If user just typed "karlbro", assume it's a handle
            handle = "@" + url
            
        if handle:
            print(f"DEBUG: Validating as handle: {handle}")
            try:
                chan_res = youtube.channels().list(
                    forHandle=handle,
                    part="id,snippet"
                ).execute()
                
                if chan_res.get("items"):
                    item = chan_res["items"][0]
                    return ChannelValidation(
                        is_valid=True,
                        channel_name=item["snippet"]["title"],
                        channel_thumbnail=item["snippet"]["thumbnails"]["default"]["url"]
                    )
            except Exception as e:
                print(f"DEBUG: forHandle failed, falling back to search: {e}")

        # 2. Fallback to Search if handle check didn't work or wasn't a handle
        search_query = url
        if "youtube.com/" in url:
            search_query = url.split("youtube.com/")[-1].replace("@", "").split("/")[0]
        
        print(f"DEBUG: Searching for channel with query: {search_query}")
        search_response = youtube.search().list(
            q=search_query,
            type="channel",
            part="id,snippet",
            maxResults=1
        ).execute()
        
        if search_response.get("items"):
            item = search_response["items"][0]
            chan_id = item["id"]["channelId"]
            # Get full channel info for high res thumbnail if possible
            chan_info = youtube.channels().list(id=chan_id, part="snippet").execute()
            
            return ChannelValidation(
                is_valid=True,
                channel_name=item["snippet"]["title"],
                channel_thumbnail=chan_info["items"][0]["snippet"]["thumbnails"]["default"]["url"]
            )

        # 3. Last stand: try as direct Channel ID
        if not url.startswith("http"):
            chan_res = youtube.channels().list(id=url, part="snippet").execute()
            if chan_res.get("items"):
                item = chan_res["items"][0]
                return ChannelValidation(
                    is_valid=True,
                    channel_name=item["snippet"]["title"],
                    channel_thumbnail=item["snippet"]["thumbnails"]["default"]["url"]
                )

        return ChannelValidation(is_valid=False, error="Channel not found")
            
    except Exception as e:
        return ChannelValidation(is_valid=False, error=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
