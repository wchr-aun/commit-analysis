git_author_stats() {
    local author="$1"
    local since="$2"
    
    if [ -z "$since" ] && [ -n "$author" ]; then
        since="$author"
        author=""
    fi
    
    if [ -z "$since" ]; then
        echo "Usage: git_stats [author] <since-date>"
        echo "Examples:"
        echo "  git_stats '2025-01-01'          # All commits since 2025-01-01"
        echo "  git_stats 'John Doe' '2025-01-01'  # Only John Doe's commits since 2025-01-01"
        return 1
    fi
    
    # Build the git log command based on whether author is provided
    local git_cmd="git log --since=\"$since\" --numstat --pretty=\"%H\""
    if [ -n "$author" ]; then
        git_cmd="$git_cmd --author=\"$author\""
    fi
    
    # Execute the command and process the output
    eval "$git_cmd" | \
    awk '
    BEGIN { commit = ""; total = 0; }
    /^[0-9a-f]{40}$/ { 
        if (commit != "" && total > 0) {
            print total;
        }
        commit = $0;
        total = 0;
    }
    /^[0-9]+\t[0-9]+\t/ {
        total += $1 + $2;
    }
    END {
        if (commit != "" && total > 0) {
            print total;
        }
    }' | \
    sort -n | \
    awk -v author="$author" -v since="$since" '
    { 
        sum += $1; 
        array[NR] = $1; 
        if ($1 > max) max = $1;  # Track maximum value
    } 
    END { 
        count = NR;
        if (count == 0) {
            if (author == "") {
                print "No commits found since " since;
            } else {
                print "No commits found for " author " since " since;
            }
            exit;
        }
        avg = sum/count;
        
        # Calculate standard deviation for all data
        sum_squared_diff = 0;
        for (i = 1; i <= count; i++) {
            diff = array[i] - avg;
            sum_squared_diff += diff * diff;
        }
        sd = sqrt(sum_squared_diff / count);
        
        # Calculate percentile positions
        p10_pos = int(count * 0.1) + 1;
        p50_pos = int(count * 0.5) + 1;  # Added 50th percentile (median)
        p60_pos = int(count * 0.6) + 1;  # Added 60th percentile
        p70_pos = int(count * 0.7) + 1;
        p80_pos = int(count * 0.8) + 1;
        p90_pos = int(count * 0.9) + 1;
        
        # Get percentile values
        p10 = array[p10_pos];
        p50 = array[p50_pos];  # 50th percentile value
        p60 = array[p60_pos];  # 60th percentile value
        p70 = array[p70_pos];
        p80 = array[p80_pos];
        p90 = array[p90_pos];
        
        # Calculate average between 10th and 90th percentiles
        trimmed_sum = 0;
        trimmed_count = 0;
        for (i = p10_pos; i <= p90_pos; i++) {
            trimmed_sum += array[i];
            trimmed_count++;
        }
        trimmed_avg = trimmed_sum / trimmed_count;
        
        # Calculate standard deviation for trimmed data
        trimmed_sum_squared_diff = 0;
        for (i = p10_pos; i <= p90_pos; i++) {
            diff = array[i] - trimmed_avg;
            trimmed_sum_squared_diff += diff * diff;
        }
        trimmed_sd = sqrt(trimmed_sum_squared_diff / trimmed_count);
        
        # Prepare the header based on whether author is provided
        if (author == "") {
            header = "Line change statistics for all commits since " since ":";
        } else {
            header = "Line change statistics for " author " since " since ":";
        }
        
        print header;
        print "Total commits: " count;
        print "Total line changes: " sum;
        printf "Standard deviation (all): %.2f\n", sd;
        printf "Standard deviation (10th-90th percentile): %.2f\n", trimmed_sd;
        printf "Average changes per commit (all): %.2f\n", avg;
        printf "Average changes per commit (10th-90th percentile): %.2f\n", trimmed_avg;
        print "10th percentile: " p10;
        print "50th percentile (median): " p50;
        print "60th percentile: " p60;
        print "70th percentile: " p70;
        print "80th percentile: " p80;
        print "90th percentile: " p90;
        print "Maximum line changes: " max;
    }'
}
