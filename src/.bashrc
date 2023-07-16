#!/usr/bin/env bash

sanitize_path()
{
    # Utility function to sanitize PATH-like specifications.
    # Do not allow
    # 1. repeated elements,
    # 2. repeated, starting, or ending `:`, and
    # 3. repeated `/`.
    printf '%s' "$1" \
        | sed 's/::*/:/g;s/^://;s_//*_/_g' \
        | awk -v 'RS=:' -v 'ORS=:' '!seen[$0]++' \
        | sed 's/:$//' \
    ;
}

discolour_enclosed_ansi()
{
    # Utility function to remove ANSI colours from strings with correctly
    # enclosed colours.
    #
    # Enclosing should be as expected by Bash for `PS1`:
    #  ^A (`\[` or `$'\001'`) to start colour codes,
    #  ^B (`\]` or `$'\002'`) to end colour codes.
    printf '%s' "${1//$'\001'*([^$'\002'])$'\002'}"
}

# Prepend old binaries to PATH
B-oldbin()
{
    export PATH="$(sanitize_path "$HOME/oldbin:$PATH")"
    hash -r
}

add_brewed_items_to_env()
{
    if [[ -z $brew_prefix ]]
    then
        return
    fi

    if [[ $(uname -s) == 'Linux' ]]
    then
        # Completion for brewed binaries
        local completions_dir="$brew_prefix/etc/bash_completion.d"
        local completion_file
        if [[ -x $completions_dir ]]
        then
            for completion_file in "$completions_dir"/*
            do
                source "$completion_file"
            done
        fi
    elif [[ $(uname -s) == 'Darwin' ]]
    then
        local brew_postgresql_latest_formula=("$(brew formulae | grep '^postgresql@' | sort -rV | head -n 1)")
        if [[ -z ${brew_postgresql_latest_formula[0]} ]]
        then
            brew_postgresql_latest_formula=()
        fi

        # Get the superior versions of common binaries
        local extra_binaries=''
        local extra_claspath=''
        local extra_dyldpath=''
        local extra_manpages=''
        local extra_pkgpaths=''

        # Keep more important items after less important ones
        local gnuitem
        for gnuitem in \
            wildfly-as \
            artifactory \
            swift \
            sphinx-doc \
            jpeg-turbo \
            sqlite \
            icu4c \
            openldap \
            cython \
            opencolorio \
            "${brew_postgresql_latest_formula[@]}" \
            libxml2 \
            texinfo \
            apr-util \
            apr \
            libarchive \
            mozjpeg \
            libxslt \
            subversion \
            expat \
            ruby \
            ssh-copy-id \
            bzip2 \
            unzip \
            zip \
            file-formula \
            krb5 \
            qt \
            libpcap \
            e2fsprogs \
            gnu-which \
            gnu-indent \
            gnu-units \
            gnu-time \
            gnu-sed \
            gnu-tar \
            openssl \
            gnu-getopt \
            gettext \
            ncurses \
            libtool \
            rpcgen \
            unifdef \
            flex \
            bison \
            curl \
            bc \
            make \
            grep \
            ed \
            m4 \
            man-db \
            gcc \
            lsof \
            util-linux \
            inetutils \
            binutils \
            findutils \
            coreutils \
        ;
        do
            local gnusubpath
            for gnusubpath in {libexec/{gnu,},,s}bin
                # 1. BSD-shadowing versions of g-prefixed items
                # 2. Items not using `gnu` in their paths
                # 3. Items requiring different paths (especially non-g-prefixed ones)
                # 4. Items installing sbins
            do
                local gnupath="$brew_prefix/opt/$gnuitem/$gnusubpath"
                if [[ -d $gnupath ]]
                then
                    extra_binaries="$gnupath:$extra_binaries"
                fi
            done

            # manpages for the commands
            local manpath="$brew_prefix/opt/$gnuitem/libexec/gnuman"
            if [[ -d $manpath ]]
            then
                extra_manpages="$manpath:$extra_manpages"
            fi

            # Different standards for different packages
            local manpath="$brew_prefix/opt/$gnuitem/libexec/man"
            if [[ -d $manpath ]]
            then
                extra_manpages="$manpath:$extra_manpages"
            fi

            # Some manpages are at a different location
            local manpath="$brew_prefix/opt/$gnuitem/share/man"
            if [[ -d $manpath ]]
            then
                extra_manpages="$manpath:$extra_manpages"
            fi

            # pkg-config for some tools
            local pkgpath="$brew_prefix/opt/$gnuitem/lib/pkgconfig"
            if [[ -d $pkgpath ]]
            then
                extra_pkgpaths="$pkgpath:$extra_pkgpaths"
            fi
        done

        local brewbinpath="$brew_prefix/bin"
        if [[ -d $brewbinpath ]]
        then
            extra_binaries="$brewbinpath:$extra_binaries"
        fi

        local brewsbinpath="$brew_prefix/sbin"
        if [[ -d $brewsbinpath ]]
        then
            extra_binaries="$brewsbinpath:$extra_binaries"
        fi

        if [[ $(id -u) != '0' ]]
        then
            local oraclepath="$ORACLE_HOME"
            if [[ -d $oraclepath ]]
            then
                extra_binaries="$oraclepath:$extra_binaries"
            fi

            local oracledyldpath="$ORACLE_HOME"
            if [[ -d $oracledyldpath ]]
            then
                extra_dyldpath="$oracledyldpath:$extra_dyldpath"
            fi

            local oracleclaspath="$ORACLE_HOME"
            if [[ -d $oracleclaspath ]]
            then
                extra_claspath="$oracleclaspath:$extra_claspath"
            fi

            local flutterpath="$HOME/flutter/bin"
            if [[ -d $flutterpath ]]
            then
                extra_binaries="$flutterpath:$extra_binaries"
            fi

            local pyenvpath="$HOME/.pyenv/bin"
            if [[ -d $pyenvpath ]]
            then
                extra_binaries="$pyenvpath:$extra_binaries"
            fi

            #local vctlpath="$HOME/.vctl/bin"
            #if [[ -d $vctlpath ]]
            #then
            #    extra_binaries="$vctlpath:$extra_binaries"
            #fi
        fi

        # Clean and export the fruits of the above labour
        if [[ $(id -u) == '0' ]]
        then
            local admin_user_home='/Users/ankitpati'
            local extra_binaries="$admin_user_home/bin:$admin_user_home/.local/bin:$extra_binaries"
            local extra_claspath="$admin_user_home/jar:$admin_user_home/.local/jar:$extra_claspath"
            local extra_dyldpath="$admin_user_home/lib:$admin_user_home/.local/lib:$extra_dyldpath"
            local extra_manpages="$admin_user_home/man:$admin_user_home/.local/share/man:$extra_manpages"
        fi

        export CLASSPATH="$(sanitize_path "$extra_claspath:$CLASSPATH")"
        export DYLD_LIBRARY_PATH="$(sanitize_path "$extra_dyldpath:$DYLD_LIBRARY_PATH")"
        export MANPATH="$(sanitize_path "$extra_manpages:$MANPATH")"
        export PATH="$(sanitize_path "$extra_binaries:$PATH")"
        export PKG_CONFIG_PATH="$(sanitize_path "$extra_pkgpaths:$PKG_CONFIG_PATH")"

        # Google Cloud SDK
        if [[ $(id -u) != '0' ]]
        then
            local gcloud_sdk="$brew_prefix/Caskroom/google-cloud-sdk/latest/google-cloud-sdk"
            if [[ -f $gcloud_sdk/path.bash.inc ]]
            then
                source "$gcloud_sdk/path.bash.inc"
            fi
            if [[ -f $gcloud_sdk/completion.bash.inc ]]
            then
                source "$gcloud_sdk/completion.bash.inc"
            fi
        fi

        # Completion for brewed binaries
        local completion_file="$brew_prefix/etc/profile.d/bash_completion.sh"
        if [[ -f $completion_file ]]
        then
            source "$completion_file"
        fi
    fi
}

setup_prompt()
{
    local clear_format='\[\e[m\]'
    local bright_green='\[\e[92m\]'
    local bright_red='\[\e[91m\]'
    local dark_cyan='\[\e[36m\]'
    local dark_magenta='\[\e[35m\]'
    local dark_yellow='\[\e[33m\]'
    local bright_cyan='\[\e[96m\]'
    local bright_magenta='\[\e[95m\]'
    local bright_yellow='\[\e[93m\]'
    local dark_blue='\[\e[34m\]'

    local exit_code="$bright_green"'$(e=$?; if ((e != 0)); then printf '"$bright_red"'; fi; printf %03u $e)'

    local year="$dark_cyan"'\D{%Y}'
    local month="$dark_magenta"'\D{%m}'
    local day_of_month="$dark_yellow"'\D{%d}'
    local hour="$bright_cyan"'\D{%H}'
    local minute="$bright_magenta"'\D{%M}'
    local second="$bright_yellow"'\D{%S}'
    local timezone="$dark_blue"'\D{%z}'
    local long_timestamp="$year$month$day_of_month$hour$minute$second$timezone"
    local short_timestamp="$hour$minute"

    local situation='\u@\h \w'
    local euid_indicator='\$'
    local coloured_euid_indicator="$bright_green"'$(e=$?; if ((e != 0)); then printf '"$bright_red"'; fi)\$'"$clear_format"

    readonly PROMPT_LEGROOM='10'

    readonly LONG_COMMON_PROMPT="$clear_format$exit_code $long_timestamp$clear_format"
    readonly SHORT_COMMON_PROMPT="$clear_format$exit_code $short_timestamp$clear_format"
    readonly SHORTEST_COMMON_PROMPT="$clear_format"

    readonly LONG_PROMPT="$LONG_COMMON_PROMPT $situation $euid_indicator "
    readonly SHORT_PROMPT="$SHORT_COMMON_PROMPT $euid_indicator "
    readonly SHORTEST_PROMPT="$SHORTEST_COMMON_PROMPT$coloured_euid_indicator "
}

set_prompt()
{
    local max_prompt_length=$((COLUMNS - PROMPT_LEGROOM))
    local long_prompt="$LONG_PROMPT"
    local short_prompt="$SHORT_PROMPT"
    local shortest_prompt="$SHORTEST_PROMPT"

    # For `git-sh`. Set `ADD_ON_PS1` in `~/.gitshrc`.
    if [[ -n $ADD_ON_PS1 ]]
    then
        long_prompt="$LONG_COMMON_PROMPT $ADD_ON_PS1"
        short_prompt="$SHORT_COMMON_PROMPT $ADD_ON_PS1"
        shortest_prompt="$SHORTEST_COMMON_PROMPT$ADD_ON_PS1"
    fi

    local expanded_long_prompt="${long_prompt@P}"
    local discoloured_expanded_long_prompt="$(discolour_enclosed_ansi "$expanded_long_prompt")"

    if ((${#discoloured_expanded_long_prompt} <= max_prompt_length))
    then
        PS1="$long_prompt"
    else
        local expanded_short_prompt="${short_prompt@P}"
        local discoloured_expanded_short_prompt="$(discolour_enclosed_ansi "$expanded_short_prompt")"

        if ((${#discoloured_expanded_short_prompt} <= max_prompt_length))
        then
            PS1="$short_prompt"
        else
            PS1="$shortest_prompt"
        fi
    fi
}

main()
{
    if [[ $(uname -s) == 'Darwin' && $(id -u) == '0' ]]
    then
        # Clear out `$PATH` before sourcing `/etc/profile` for root.
        #
        # This is necessary because `sudo -i` on macOS doesn't blank out `$PATH`;
        # it passes it unchanged from the sudo'ing user to root.
        #
        # shellcheck disable=SC2123
        PATH=''
    fi

    if [[ -n $BASHRC_MAIN_SOURCED ]]
    then
        return 0
    fi

    readonly BASHRC_MAIN_SOURCED='1'

    # Source global definitions
    local global_profile='/etc/profile'
    # `$PROFILEREAD` is openSUSE-specific at the time of writing.
    if [[ -z $PROFILEREAD && -f $global_profile ]]
    then
        source "$global_profile"
    fi

    mesg n || :

    if [[ $(uname -s) == 'Linux' ]]
    then
        export PATH="$(sanitize_path "/home/linuxbrew/.linuxbrew/bin:$PATH")"
    fi

    local brew_prefix="$(command -v brew &>/dev/null && brew --prefix)"

    # Ensure `source`s below this see the correct `$MANPATH`.
    local manpath="$MANPATH"
    unset MANPATH
    export MANPATH="$(sanitize_path "$manpath:$(manpath)")"

    # Text editors
    export EDITOR='vim'
    export MERGE='vimdiff'

    # Telemetry
    export DOTNET_CLI_TELEMETRY_OPTOUT='1'
    export HOMEBREW_NO_ANALYTICS='1'
    export POWERSHELL_TELEMETRY_OPTOUT='1'
    export SRC_DISABLE_USER_AGENT_TELEMETRY='1'

    # History configuration
    shopt -s histappend
    unset HISTTIMEFORMAT
    HISTCONTROL='ignoreboth'
    HISTFILESIZE=''
    HISTSIZE=''
    if ! printf '%s\n' "$PROMPT_COMMAND" | grep -q '\bhistory\b'
    then
        PROMPT_COMMAND="$(printf 'history -a; history -n; set_prompt; %s\n' "$PROMPT_COMMAND" \
                          | sed 's/__vte_prompt_command//g')"
    fi

    # Brew Prevent Time-Consuming Activities
    export HOMEBREW_NO_BOTTLE_SOURCE_FALLBACK='1'

    # Secure Brew
    export HOMEBREW_NO_INSECURE_REDIRECT='1'

    # Syntax-highlighted Brew Output
    export HOMEBREW_BAT='1'

    # RLWrap
    export RLWRAP_EDITOR="vim '+call cursor(%L,%C)'"
    export RLWRAP_HOME="$HOME/.rlwrap"

    # ripgrep
    export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

    # Oracle Database
    if [[ $(uname -s) == 'Darwin' ]]
    then
        local instantclient="$(brew --prefix)/Cellar/instantclient-basic"

        # shellcheck disable=2012
        export ORACLE_HOME="$instantclient/$(ls -vr "$instantclient" | head -1)/"
    fi

    # PostgreSQL
    export PGSSLMODE='verify-full'

    # SDKMAN!
    export SDKMAN_DIR="$HOME/.sdkman/"

    # Android
    export ANDROID_HOME="$HOME/Android/Sdk/"

    # NPM
    export NPM_PACKAGES="$HOME/.npm/packages/"

    # Python
    export MYPYPATH="$HOME/.mypy_stubs/"
    export MYPY_CACHE_DIR="$HOME/.mypy_cache/"
    export PYENV_ROOT="$HOME/.pyenv/"

    # Perl
    export PERL5LIB="$(sanitize_path "$HOME/perl5/lib/perl5:$PERL5LIB")"
    export PERLBREW_CPAN_MIRROR='https://www.cpan.org/'
    export PERLCRITIC="$HOME/.perlcriticrc"
    export PERL_CPANM_OPT='--from https://www.cpan.org/ --verify'
    export PERL_LOCAL_LIB_ROOT="$(sanitize_path "$HOME/perl5:$PERL_LOCAL_LIB_ROOT")"
    export PERL_MB_OPT="--install_base '$HOME/perl5'"
    export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"

    # Podman
    if command -v podman &>/dev/null && [[ -n $XDG_RUNTIME_DIR ]]
    then
        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    fi

    # No `man` Prompts on Namesake Pages
    export MAN_POSIXLY_CORRECT='1'

    alias chomp='perl -pi -E "chomp if eof"'
    alias cpan-outdated='cpan-outdated --mirror="$PERLBREW_CPAN_MIRROR"'
    alias git-sh='exec git-sh'
    alias grep='grep --color=auto'
    alias grepp='grep -P'
    alias l.='ls -d .*'
    alias l='ls -CF'
    alias la='ls -A'
    alias ll='ls -alF'
    # shellcheck disable=SC2262
    alias ls='ls --color=auto'
    alias mosh='exec mosh'
    alias ncdu='ncdu --color dark'
    alias podchecker='podchecker -warnings -warnings -warnings'
    alias ssh-copy-id='ssh-copy-id -oPasswordAuthentication=yes'
    alias ssh='exec ssh'
    alias telnet='exec telnet'
    alias tohex="hexdump -ve '1/1 \"%.2x\" '"
    alias tree='tree -I ".git|.terraform|node_modules"'
    # shellcheck disable=SC2154
    alias unchomp='sed -i -e \$a\\ '

    add_brewed_items_to_env
    unset -f add_brewed_items_to_env

    setup_prompt
    unset -f setup_prompt
    set_prompt

    # Bash
    export -f sanitize_path

    if [[ $(id -u) != '0' ]]
    then
        # pyenv
        if [[ -d $PYENV_ROOT ]]
        then
            source <(pyenv init -)
        fi

        # Perlbrew
        local perlbrew_bashrc="$HOME/perl5/perlbrew/etc/bashrc"
        if [[ -f $perlbrew_bashrc ]]
        then
            source "$perlbrew_bashrc"
        fi

        # Perl local::lib
        export PATH="$(sanitize_path "$HOME/perl5/bin:$PATH")"
        export MANPATH="$(sanitize_path "$HOME/perl5/man:$MANPATH")"

        # Cargo
        export PATH="$(sanitize_path "$HOME/.cargo/bin:$PATH")"

        # Go
        export PATH="$(sanitize_path "$HOME/go/bin:$PATH")"

        # Composer
        export PATH="$(sanitize_path "$HOME/.composer/vendor/bin:$PATH")"

        # NPM
        #npm config set prefix "$NPM_PACKAGES"
        export PATH="$(sanitize_path "$NPM_PACKAGES/bin:$PATH")"

        # SDKMAN!
        local sdkman_init="$SDKMAN_DIR/bin/sdkman-init.sh"
        if [[ -f $sdkman_init ]]
        then
            source "$sdkman_init"
        fi

        # Ruby
        local ruby_gems="$HOME/.local/share/gem/ruby"
        if [[ -n $(ls "$ruby_gems" 2>/dev/null) ]]
        then
            # shellcheck disable=2012
            export PATH="$(sanitize_path "$ruby_gems/$(ls -vr "$ruby_gems" | head -1)/bin:$PATH")"
        fi

        # .NET
        export PATH="$(sanitize_path "$HOME/.dotnet/tools:$PATH")"

        # Android
        export PATH="$(sanitize_path "$HOME/Android/Sdk/platform-tools:$PATH")"

        # User-installed tools
        export CLASSPATH="$(sanitize_path "$HOME/jar:$HOME/.local/jar:$CLASSPATH")"
        if [[ $(uname -s) == 'Darwin' ]]
        then
            export DYLD_LIBRARY_PATH="$(sanitize_path "$HOME/lib:$HOME/.local/lib:$DYLD_LIBRARY_PATH")"
        fi
        export MANPATH="$(sanitize_path "$HOME/man:$HOME/.local/share/man:$MANPATH")"
        export PATH="$(sanitize_path "$HOME/bin:$HOME/.local/bin:$PATH")"
        export PERL5LIB="$(sanitize_path "$HOME/lib/perl5:$HOME/.local/lib/perl5:$PERL5LIB")"
    fi

    # Colours for `tree`
    source <(dircolors -b)

    return 0
}

# Invoke `main` & cleanup
main
unset -f main
