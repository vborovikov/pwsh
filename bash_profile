#!/usr/bin/env bash

# Git status parser
declare -g GIT_HAS_GIT=false
command -v git &>/dev/null && GIT_HAS_GIT=true

declare -g GIT_HAS_STATUS=false
declare -g GIT_BRANCH=""
declare -g GIT_COMMIT=""
declare -g GIT_NUMBER=""
declare -g GIT_HAS_CHANGES=false
declare -g GIT_MODIFIED_STAGED=0
declare -g GIT_ADDED_STAGED=0
declare -g GIT_DELETED_STAGED=0
declare -g GIT_MODIFIED_UNSTAGED=0
declare -g GIT_ADDED_UNSTAGED=0
declare -g GIT_DELETED_UNSTAGED=0
declare -g GIT_UNTRACKED=0

update_git_status() {
    if [[ "$GIT_HAS_GIT" != true ]]; then
        return
    fi

    local status
    status=$(git status --porcelain 2>&1)
    if [[ $? -ne 0 ]]; then
        GIT_HAS_STATUS=false
        return
    fi

    GIT_HAS_STATUS=true
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>&1)
    GIT_COMMIT=$(git log -1 --format=%h 2>&1)
    GIT_NUMBER=$(git rev-list --count HEAD 2>&1)

    GIT_HAS_CHANGES=false
    if [[ -n "$status" ]]; then
        GIT_HAS_CHANGES=true
    fi

    GIT_MODIFIED_STAGED=0
    GIT_ADDED_STAGED=0
    GIT_DELETED_STAGED=0
    GIT_MODIFIED_UNSTAGED=0
    GIT_ADDED_UNSTAGED=0
    GIT_DELETED_UNSTAGED=0
    GIT_UNTRACKED=0

    if [[ "$GIT_HAS_CHANGES" == true ]]; then
        while IFS= read -r line; do
            if [[ "$line" == "?? "* ]]; then
                ((GIT_UNTRACKED++))
            else
                if [[ "${line:0:1}" != " " ]]; then
                    case "${line:0:1}" in
                        M|R) ((GIT_MODIFIED_STAGED++)) ;;
                        A)   ((GIT_ADDED_STAGED++)) ;;
                        D)   ((GIT_DELETED_STAGED++)) ;;
                    esac
                fi
                if [[ "${line:1:1}" != " " ]]; then
                    case "${line:1:1}" in
                        M|R) ((GIT_MODIFIED_UNSTAGED++)) ;;
                        A)   ((GIT_ADDED_UNSTAGED++)) ;;
                        D)   ((GIT_DELETED_UNSTAGED++)) ;;
                    esac
                fi
            fi
        done <<< "$status"
    fi
}

git_status_to_text() {
    if [[ "$GIT_HAS_STATUS" != true ]]; then
        echo ""
        return
    fi

    local e=$'\033'

    if [[ "$GIT_HAS_CHANGES" == true ]]; then
        # branch name
        echo -ne "${e}[91m${GIT_BRANCH}${e}[0m"

        # [
        echo -ne "${e}[91;2m[${e}[22;0m"

        # modified
        echo -ne "${e}[94;2m~${e}[22;0m"
        if [[ $GIT_MODIFIED_STAGED -gt 0 ]]; then echo -ne "${e}[92m${GIT_MODIFIED_STAGED}${e}[0m"; else echo -ne "${e}[92;2m0${e}[22;0m"; fi
        if [[ $GIT_MODIFIED_UNSTAGED -gt 0 ]]; then echo -ne "${e}[91m${GIT_MODIFIED_UNSTAGED}${e}[0m"; else echo -ne "${e}[91;2m0${e}[22;0m"; fi

        # added
        echo -ne "${e}[94;2m+${e}[22;0m"
        if [[ $GIT_ADDED_STAGED -gt 0 ]]; then echo -ne "${e}[92m${GIT_ADDED_STAGED}${e}[0m"; else echo -ne "${e}[92;2m0${e}[22;0m"; fi
        if [[ $GIT_ADDED_UNSTAGED -gt 0 ]]; then echo -ne "${e}[91m${GIT_ADDED_UNSTAGED}${e}[0m"; else echo -ne "${e}[91;2m0${e}[22;0m"; fi

        # deleted
        echo -ne "${e}[94;2m-${e}[22;0m"
        if [[ $GIT_DELETED_STAGED -gt 0 ]]; then echo -ne "${e}[92m${GIT_DELETED_STAGED}${e}[0m"; else echo -ne "${e}[92;2m0${e}[22;0m"; fi
        if [[ $GIT_DELETED_UNSTAGED -gt 0 ]]; then echo -ne "${e}[91m${GIT_DELETED_UNSTAGED}${e}[0m"; else echo -ne "${e}[91;2m0${e}[22;0m"; fi

        # untracked
        echo -ne "${e}[94;2m:${e}[22;0m"
        if [[ $GIT_UNTRACKED -gt 0 ]]; then echo -ne "${e}[93m${GIT_UNTRACKED}${e}[0m"; else echo -ne "${e}[93;2m0${e}[22;0m"; fi

        # ]
        echo -ne "${e}[91;2m]${e}[22;0m"

        # commit hash
        echo -ne "${e}[94m${e}[2m#${e}[22m${GIT_COMMIT}${e}[0m"
        # number of commits
        echo -ne "${e}[33m${e}[2m;${e}[22m${GIT_NUMBER}${e}[0m"
    else
        # branch name
        echo -ne "${e}[92m${GIT_BRANCH}${e}[0m"
        # commit hash
        echo -ne "${e}[94m${e}[2m#${e}[22m${GIT_COMMIT}${e}[0m"
        # number of commits
        echo -ne "${e}[33m${e}[2m;${e}[22m${GIT_NUMBER}${e}[0m"
    fi
}

# Project toolset detector
declare -g DOTNET_STUB_MONIKER=".net"

declare -g PROJECT_HAS_PROJECT=false
declare -g PROJECT_MONIKER=""

detect_dotnet_project() {
    local csprojPath="$PWD"
    local csproj=""

    while [[ -z "$csproj" ]]; do
        csproj=$(find "$csprojPath" -maxdepth 1 -name "*.csproj" -type f 2>/dev/null | head -n 1)
        if [[ -n "$csproj" ]]; then
            break
        fi
    
    local parentDir=$(dirname "$csprojPath")
    if [[ "$parentDir" == "$csprojPath" || "$csprojPath" == "$HOME" || "$csprojPath" == "" ]]; then
            break
        fi
    csprojPath="$parentDir"
    done

    if [[ -n "$csproj" ]]; then
        get_dotnet_moniker "$csproj"
    else
        PROJECT_MONIKER=""
    fi
}

get_dotnet_moniker() {
    local csproj="$1"
    local moniker=""

    # single target framework
    moniker=$(grep -m1 -oP '(?<=<TargetFramework>).*?(?=</TargetFramework>)' "$csproj" 2>/dev/null)

    # multiple target frameworks
    if [[ -z "$moniker" ]]; then
        moniker=$(grep -m1 -oP '(?<=<TargetFrameworks>).*?(?=</TargetFrameworks>)' "$csproj" 2>/dev/null)
    fi

    # old projects with MSBuild namespace
    if [[ -z "$moniker" ]]; then
        moniker=$(grep -m1 -oP '(?<=TargetFrameworkVersion>).*?(?=</TargetFrameworkVersion>)' "$csproj" 2>/dev/null)
        if [[ -n "$moniker" ]]; then
            moniker="${moniker/v/net}"
        fi
    fi

    # check Directory.Build.props for TargetFramework or TargetFrameworks
    if [[ -z "$moniker" ]]; then
        local propsDir=$(dirname "$csproj")
        while [[ -n "$propsDir" && "$propsDir" != "$HOME" && "$propsDir" != "" ]]; do
            local propsFile="${propsDir}/Directory.Build.props"
            if [[ -f "$propsFile" ]]; then
                local framework=""
                framework=$(grep -m1 -oP '(?<=TargetFramework>).*?(?=</TargetFramework>)' "$propsFile" 2>/dev/null)
                if [[ -z "$framework" ]]; then
                    framework=$(grep -m1 -oP '(?<=TargetFrameworks>).*?(?=</TargetFrameworks>)' "$propsFile" 2>/dev/null)
                fi

                if [[ -n "$framework" ]]; then
                    moniker="$framework"
                    break
                fi
            fi

            local parentDir=$(dirname "$propsDir")
            if [[ "$parentDir" == "$propsDir" ]]; then
                break
            fi
            propsDir="$parentDir"
        done
    fi

    if [[ -n "$moniker" ]]; then
        if [[ "$moniker" == *'$'* ]]; then
            PROJECT_MONIKER="$DOTNET_STUB_MONIKER"
        else
            local e=$'\033'
            PROJECT_MONIKER=".${moniker//;/${e}[2m;${e}[22m.}"
        fi
    else
        PROJECT_MONIKER=""
    fi
}

update_project_toolset() {
    detect_dotnet_project
    if [[ -n "$PROJECT_MONIKER" ]]; then
        PROJECT_HAS_PROJECT=true
    else
        PROJECT_HAS_PROJECT=false
    fi
}

# Window title resolver
declare -g PS_WINDOW_TITLE=""

update_window_title() {
    local titlePath="$PWD"
    local title=$(basename "$titlePath")

    local -a skip_names=( '^net[0-9]+\.[0-9]$', 'Debug', 'Release', 'bin', 'obj', 'src', 'db', 'test', 'build', 'pkg', 'code', 'game' )

    while true; do
        local skip=false
        for skipName in "${skip_names[@]}"; do
            if [[ "$skipName" == ^* ]]; then
                if [[ "$title" =~ $skipName ]]; then
                    skip=true
                    break
                fi
            else
                if [[ "$title" == "$skipName" ]]; then
                    skip=true
                    break
                fi
            fi
        done

        if [[ "$skip" != true ]]; then
            break
        fi
    
    local parentTitlePath=$(dirname "$titlePath")
    if [[ "$parentTitlePath" == "$titlePath" || -z "$titlePath" ]]; then
            break
        fi
    titlePath="$parentTitlePath"
        title=$(basename "$titlePath")
    done

    if [[ ${#title} -gt 15 ]]; then
        title="${title:0:15}"$'\xe2\x80\xa6'
    fi

    if [[ ${#title} -gt 0 ]]; then
        if [[ -n "$PS_WINDOW_TITLE" ]]; then
            echo -ne "\033]0;${title} - ${PS_WINDOW_TITLE}\007"
        else
            echo -ne "\033]0;${title}\007"
        fi
    fi
}

# Prompt
# Replaces $HOME part of the current path with '~'
# time | path | git | .net
#
function prompt() {
    local err=$?

    # decoration symbols
    local e=$'\033'
  
  local ps_up="${e}[2m"$'\u250c'"${e}[22m"
  local ps_md="${e}[2m"$'\u2502'"${e}[22m"
  local ps_dn="${e}[2m"$'\u2514'"${e}[22m"
  local ps_cm="${e}[2m"$'\u2500'$'\u25ba'"${e}[22m"
  
    # error check
    if [[ $err -ne 0 ]]; then
        ps_up="${e}[91m${ps_up}${e}[0m"
        ps_md="${e}[91m${ps_md}${e}[0m"
        ps_dn="${e}[91m${ps_dn}${e}[0m"
        ps_cm="${e}[91m${ps_cm}${e}[0m"
    fi

    # date and time
    local time=$(date '+%d.%m %H:%M')

    # current path
    local path="$PWD"
    local pathLength=${#path}
    if [[ "$path" == "$HOME"/* ]]; then
        path="${path/#$HOME/\~}"
        pathLength=${#path}
    fi
    path="${path//\//$e[2m/$e[22m}"

    # window title
    update_window_title

    # git status
    update_git_status

    # project toolset
    update_project_toolset

    # prompt construction

    # prompt start
    local prompt_str=$'\n'"${ps_up}"

    # date and time
    prompt_str+=" ${e}[36m${e}[2m"$'\u221e'" ${time}${e}[0m"

    # user and host
    prompt_str+=" ${e}[37m${e}[2m"$'\u2302'" ${e}[0;92m${USER}${e}[2m@${e}[22m${e}[0m${e}[93m${HOSTNAME}${e}[2m:${e}[22m${e}[0m"
  
    # current path
    prompt_str+="${e}[37m${path}${e}[0m"
  
    # new line if path is too long for the window width
    local window_width=$(tput cols 2>/dev/null || echo 80)
    if [[ $pathLength -gt $((window_width / 2)) ]]; then
        prompt_str+=$'\n'"${ps_md}"
    fi

    # git status
    if [[ "$GIT_HAS_STATUS" == true ]]; then
    prompt_str+=" ${e}[33m${e}[2m"$'\u028e'"${e}[0m $(git_status_to_text)"
    fi

    # project toolset
    if [[ "$PROJECT_HAS_PROJECT" == true ]]; then
    prompt_str+=" ${e}[95m${e}[2m"$'\u2261'"${e}[0m ${PROJECT_MONIKER}"
    fi

    # prompt end
    prompt_str+=$'\n'"${ps_dn}${ps_cm} "

    PS1="${prompt_str}"
}

# Set prompt
PROMPT_COMMAND=prompt

# Aliases
alias touch='touch'
alias file='find'
alias open='xdg-open'
alias edit='code'
