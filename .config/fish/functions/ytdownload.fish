function ytdownload
    if string match -q -- "*list=*" $argv
        # Playlist: Saves into a folder, files are just "001 - Title.mp4"
        yt-dlp -o "%(playlist)s/%(playlist_index)03d - %(title)s.%(ext)s" $argv
    else
        # Single Video: Saves directly to current directory as "Title.mp4"
        yt-dlp -o "%(title)s.%(ext)s" $argv
    end
end
