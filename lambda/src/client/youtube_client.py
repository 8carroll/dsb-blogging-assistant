import textwrap

from googleapiclient.discovery import build
from youtube_transcript_api import YouTubeTranscriptApi

from client.ssm_client import SsmClient

CHANNEL_NAME = "The DevSec Blueprint (DSB)"


class YouTubeClient:

    def __init__(self):
        self.youtube_client = self._create_authenticated_client()

    def get_video_id(self, video_name=None):
        # Call the search.list method to retrieve videos for the channel
        search_response = (
            self.youtube_client.search()
            .list(part="snippet", q=CHANNEL_NAME, type="channel")
            .execute()
        )

        # Extract the channel ID from the search results
        channel_id = search_response["items"][0]["id"]["channelId"]

        # Call the search.list method again to retrieve videos for the channel using its ID
        if video_name is None:
            video = (
                self.youtube_client.search()
                .list(
                    part="snippet",
                    channelId=channel_id,
                    type="video",
                    order="date",
                )
                .execute()["items"][0]
            )
        else:
            videos = (
                self.youtube_client.search()
                .list(
                    part="snippet",
                    channelId=channel_id,
                    type="video",
                    order="date",
                )
                .execute()["items"]
            )

            for _video in videos:
                if _video["snippet"]["title"] == video_name:
                    video = _video
                    break

        return video["id"]["videoId"], video["snippet"]["title"]

    def get_video_transcript(self, latest_video_id, max_line_width=80):
        transcript = YouTubeTranscriptApi.get_transcript(
            video_id=latest_video_id, languages=["en"]
        )

        formatted_transcript = ""
        wrapper = textwrap.TextWrapper(width=max_line_width)

        for entry in transcript:
            wrapped_text = wrapper.fill(text=entry["text"])
            formatted_transcript += wrapped_text + "\n"
        return formatted_transcript

    def _create_authenticated_client(self):
        ssm_client = SsmClient()
        api_key = ssm_client.get_parameter("credentials/youtube/auth_token")
        return build("youtube", "v3", developerKey=api_key)
