#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <ctype.h>
#include <mpd/client.h>


void strlower(char* szDestination, char* szSource);


int main(int argc, char ** argv)
{
	struct mpd_connection *conn = mpd_connection_new(NULL, 0, 0);
	if (conn == NULL) {
		fputs("Out of memory\n", stderr);
		return 1;
	}
	
//	if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS)
//		printErrorAndExit(conn);
	
	
	if (!mpd_send_list_all(conn, ""))
	{
	//	printErrorAndExit(conn);
	}
	
	
	struct mpd_song *song;
	while ((song = mpd_recv_song(conn)) != NULL)
	{
//		printf("%s\n", charset_from_utf8(mpd_song_get_uri(song)));

		char* szSong = (char*)mpd_song_get_uri(song);
		
		char szLowerCaseSong[256];
		strlower(szLowerCaseSong, szSong);
		
		bool fMatching = true;
		char* szSongPart = (char*)&szLowerCaseSong;
		for (int i=1; i<argc; i++)
		{
			char szSearchWord[256];
			strlower(szSearchWord, argv[i]);
			
			char* szMatchStart = strstr(szSongPart, szSearchWord);
			if (szMatchStart == NULL)
			{
				fMatching = false;
				break;
			}
			else
			{
				szSongPart = szMatchStart + strlen(szSearchWord);
			}
		}
		
		if (fMatching)
		{
			printf("%s\n", szSong);
		}
		
		mpd_song_free(song);
	}
	
//	if (mpd_connection_get_error(conn) != MPD_ERROR_SUCCESS)
//		printErrorAndExit(conn);
	
	
//	if (!mpd_response_finish(conn))
//		printErrorAndExit(conn);
	
	
	mpd_connection_free(conn);
	
	return 0;
}


void strlower(char* szDestination, char* szSource)
{
	int i = 0;
	while (szSource[i] != '\0')
	{
		szDestination[i] = tolower(szSource[i]);
		i++;
	}
	szDestination[i] = '\0';
}
