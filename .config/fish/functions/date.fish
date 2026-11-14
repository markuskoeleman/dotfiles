function date --wraps="command date '+%a %b %d %H:%M:%S %Z %Y'" --description "alias date=command date '+%a %b %d %H:%M:%S %Z %Y'"
    command date '+%a %b %d %H:%M:%S %Z %Y' $argv
end
