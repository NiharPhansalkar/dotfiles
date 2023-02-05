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

B-clean-cache()
{
    printf 'Removing SSH known_hosts Backup...\n'
    rm "$HOME/.ssh/known_hosts.old"

    printf 'Uninstalling dangling Homebrew packages...\n'
    brew autoremove

    printf 'Removing the Homebrew Build Cache...\n'
    brew cleanup --prune=all

    printf 'Removing the Perlbrew Build Cache...\n'
    perlbrew clean

    printf 'Removing the CPAN.pm Cache...\n'
    rm -rf "$HOME/.cpan/"{'build/','sources/','Metadata'}

    printf 'Removing the CPANM Work Cache...\n'
    rm -rf "$HOME/.cpanm/"{'work/','build.log','latest-build'}

    printf 'Removing the PIP Cache...\n'
    rm -rf "$HOME/.cache/pip/"
    rm -rf "$HOME/Library/Caches/pip/"

    printf 'Removing the Maven Cache...\n'
    rm -rf "$HOME/.m2/repository/"

    printf 'Removing Maccy SQLite DB (only works if Maccy is not running)...\n'
    rm "$HOME/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/Storage.sqlite"*

    printf 'Removing the QuickLook Cache...\n'
    qlmanage -r cache

    # TODO: [macOS] find & vacuum/remove all NSPersistentContainer SQLite DBs

    :
}

# Compact Homebrew git repositories
B-brew-compact()
{
    local brew_prefix="$(brew --prefix)"

    printf 'Running `git cleanup` on Homebrew...\n'
    local brewtap
    for brewtap in "$brew_prefix/Homebrew" \
                   "$brew_prefix/Homebrew/Library/Taps/"*/*
    do
        git -C "$brewtap" cleanup
    done

    :
}

# Prepend old binaries to PATH
B-oldbin()
{
    export PATH="$(sanitize_path "$HOME/oldbin:$PATH")"
    hash -r
}

add_brewed_items_to_env()
{
    test -z "$brew_prefix" && \
        return

    if [[ $(uname -s) == 'Linux' ]]
    then
        # Completion for brewed binaries
        local completions_dir="$brew_prefix/etc/bash_completion.d"
        local completion_file
        test -x "$completions_dir" && \
            for completion_file in "$completions_dir"/*
            do
                source "$completion_file"
            done
    elif [[ $(uname -s) == 'Darwin' ]]
    then
        local brew_postgresql_latest_formula=("$(brew formulae | grep '^postgresql@' | sort -rV | head -n 1)")
        test -z "${brew_postgresql_latest_formula[0]}" && \
            brew_postgresql_latest_formula=()

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
            # BSD-shadowing versions of g-prefixed items
            local gnupath="$brew_prefix/opt/$gnuitem/libexec/gnubin"
            test -d "$gnupath" && extra_binaries="$gnupath:$extra_binaries"

            # Some items prefer not to use `gnu` in their paths
            local gnupath="$brew_prefix/opt/$gnuitem/libexec/bin"
            test -d "$gnupath" && extra_binaries="$gnupath:$extra_binaries"

            # Some items, especially the non-g-prefixed ones, require different paths
            local gnupath="$brew_prefix/opt/$gnuitem/bin"
            test -d "$gnupath" && extra_binaries="$gnupath:$extra_binaries"

            # Some items install sbins
            local gnupath="$brew_prefix/opt/$gnuitem/sbin"
            test -d "$gnupath" && extra_binaries="$gnupath:$extra_binaries"

            # manpages for the commands
            local manpath="$brew_prefix/opt/$gnuitem/libexec/gnuman"
            test -d "$manpath" && extra_manpages="$manpath:$extra_manpages"

            # Different standards for different packages
            local manpath="$brew_prefix/opt/$gnuitem/libexec/man"
            test -d "$manpath" && extra_manpages="$manpath:$extra_manpages"

            # Some manpages are at a different location
            local manpath="$brew_prefix/opt/$gnuitem/share/man"
            test -d "$manpath" && extra_manpages="$manpath:$extra_manpages"

            # pkg-config for some tools
            local pkgpath="$brew_prefix/opt/$gnuitem/lib/pkgconfig"
            test -d "$pkgpath" && extra_pkgpaths="$pkgpath:$extra_pkgpaths"
        done

        local brewbinpath="$brew_prefix/bin"
        test -d "$brewbinpath" && extra_binaries="$brewbinpath:$extra_binaries"

        local brewsbinpath="$brew_prefix/sbin"
        test -d "$brewsbinpath" && extra_binaries="$brewsbinpath:$extra_binaries"

        if [[ $(id -u) != '0' ]]
        then
            local oraclepath="$ORACLE_HOME"
            test -d "$oraclepath" && extra_binaries="$oraclepath:$extra_binaries"

            local oracledyldpath="$ORACLE_HOME"
            test -d "$oracledyldpath" && extra_dyldpath="$oracledyldpath:$extra_dyldpath"

            local oracleclaspath="$ORACLE_HOME"
            test -d "$oracleclaspath" && extra_claspath="$oracleclaspath:$extra_claspath"

            local flutterpath="$HOME/flutter/bin"
            test -d "$flutterpath" && extra_binaries="$flutterpath:$extra_binaries"

            local pyenvpath="$HOME/.pyenv/bin"
            test -d "$pyenvpath" && extra_binaries="$pyenvpath:$extra_binaries"

            #local vctlpath="$HOME/.vctl/bin"
            #test -d "$vctlpath" && extra_binaries="$vctlpath:$extra_binaries"
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
            test -f "$gcloud_sdk/path.bash.inc" && \
                source "$gcloud_sdk/path.bash.inc"
            test -f "$gcloud_sdk/completion.bash.inc" && \
                source "$gcloud_sdk/completion.bash.inc"
        fi

        # Completion for brewed binaries
        local completion_file="$brew_prefix/etc/profile.d/bash_completion.sh"
        test -f "$completion_file" && \
            source "$completion_file"
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

    test -n "$BASHRC_MAIN_SOURCED" && \
        return 0

    readonly BASHRC_MAIN_SOURCED='1'

    # Source global definitions
    local global_profile='/etc/profile'
    # `$PROFILEREAD` is openSUSE-specific at the time of writing.
    # shellcheck disable=SC2154
    test -z "$PROFILEREAD" -a -f "$global_profile" && \
        source "$global_profile"

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
    export HISTCONTROL='ignoreboth'
    export HISTFILESIZE=''
    export HISTSIZE=''
    test -z "$(printf '%s\n' "$PROMPT_COMMAND" | grep '\bhistory\b')" && \
        export PROMPT_COMMAND="$(printf 'history -a; history -n; %s\n' "$PROMPT_COMMAND" \
                                 | sed 's/__vte_prompt_command//g')"

    # Brew Prevent Time-Consuming Activities
    export HOMEBREW_NO_AUTO_UPDATE='1'
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
    export ORACLE_HOME=''
    export ORACLE_SID=''
    alias S-ora-tns-rqlplus='rlwrap sqlplus user/pass@tns'
    alias S-ora-tns-sqlplus='sqlplus user/pass@tns'
    alias S-ora-tns-yasql='yasql user/pass@tns'

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

    alias brew-cu='brew cu --no-brew-update'
    alias chomp='perl -pi -E "chomp if eof"'
    alias cpan-outdated='cpan-outdated --mirror="$PERLBREW_CPAN_MIRROR"'
    alias git-sh='exec git-sh'
    # shellcheck disable=SC2262
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

    # Bash
    export -f sanitize_path

    if [[ $(id -u) != '0' ]]
    then
        # pyenv
        # shellcheck disable=SC2154
        test -d "$PYENV_ROOT" && \
            source <(pyenv init -)

        # Perlbrew
        local perlbrew_bashrc="$HOME/perl5/perlbrew/etc/bashrc"
        test -f "$perlbrew_bashrc" && \
            source "$perlbrew_bashrc"

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
        test -f "$sdkman_init" && \
            source "$sdkman_init"

        # Ruby
        local ruby_gems="$HOME/.local/share/gem/ruby"
        # shellcheck disable=2012,2263
        test -n "$(ls "$ruby_gems" 2>/dev/null)" && \
            export PATH="$(sanitize_path "$ruby_gems/$(ls -vr "$ruby_gems" | head -1)/bin:$PATH")"

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
