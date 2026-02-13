from youtube_transcript_api import YouTubeTranscriptApi

video_ids = ['PnJPBiVvVX4']
yt = YouTubeTranscriptApi()

try:
    print("Calling yt.list('PnJPBiVvVX4')...")
    res = yt.list_transcripts('PnJPBiVvVX4') # This failed before.
    # In main.py it was `yt.list`.
    # But wait, step 25 `main.py` line 114 says: `transcript_list = yt_transcript_api.list(video_id)`
    
    # Let's try `list` method specifically.
    if hasattr(yt, 'list'):
        print("Function `list` Found.")
        t_list = yt.list('PnJPBiVvVX4')
        print(f"List Result: {t_list}")
        
        # main.py does: `transcript = transcript_list.find_transcript(['en'])`
        t = t_list.find_transcript(['en'])
        print(f"Found partial transcript: {t}")
        data = t.fetch()
        print(f"Fetch success! Length: {len(data)}")
    else:
        print("Method `list` NOT FOUND on instance.")
        # Try static
        res = YouTubeTranscriptApi.get_transcript('PnJPBiVvVX4')
        print(f"Static get_transcript success: {len(res)}")

except Exception as e:
    print(f"FAIL: {e}")
    import traceback
    traceback.print_exc()
