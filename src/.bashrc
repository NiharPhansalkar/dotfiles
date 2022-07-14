#!/usr/bin/env bash

sanitize_path()
{
    # Utility function to sanitize PATH-like specifications.
    # Do not allow
    # 1. repeated elements,
    # 2. repeated, starting, or ending `:`, and
    # 3. repeated `/`.
    echo -n "$1" \
        | sed 's/::*/:/g;s/^://;s_//*_/_g' \
        | awk -v 'RS=:' -v 'ORS=:' '!seen[$0]++' \
        | sed 's/:$//' \
    ;
}

B-delds()
{
    echo 'Removing the following files...'
    find "$HOME" -not \( -path "$HOME/Mounts" -prune \) \
           -regextype egrep \
           -regex '.*(\.(DS_Store|AppleDouble|AppleDesktop)|Thumbs\.db)$' \
           -print \
           -exec rm -rf {} +

    echo 'Removing broken symlinks...'
    find "$HOME" -not \( -path "$HOME/Mounts" -prune \) \
            -type l \
            ! -exec test -e {} \; \
            -print \
            -exec rm -rf {} +

    command -v qlmanage &>/dev/null && \
        echo 'Removing the QuickLook Cache...' && \
        qlmanage -r cache
}

B-clean-cache()
{
    echo 'Uninstalling dangling Homebrew packages...'
    brew autoremove

    echo 'Removing the Homebrew Build Cache...'
    brew cleanup --prune=all

    echo 'Removing the Perlbrew Build Cache...'
    perlbrew clean

    echo 'Removing the CPAN.pm Cache...'
    rm -rf "$HOME/.cpan/"{'build/','sources/','Metadata'}

    echo 'Removing the CPANM Work Cache...'
    rm -rf "$HOME/.cpanm/"{'work/','build.log','latest-build'}

    echo 'Removing the PIP Cache...'
    rm -rf "$HOME/.cache/pip/"
}

# Compact Homebrew git repositories
B-brew-compact()
{
    local brew_prefix="$(brew --prefix)"

    echo 'Running `git cleanup` on Homebrew...'
    local brewtap
    for brewtap in "$brew_prefix/Homebrew" \
                   "$brew_prefix/Homebrew/Library/Taps/"*/*
    do
        git -C "$brewtap" cleanup
    done
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

    # Completion for brewed binaries
    local completions_dir="$brew_prefix/etc/bash_completion.d"
    local completion_file
    test -x "$completions_dir" && \
        for completion_file in "$completions_dir"/*
        do
            source "$completion_file"
        done
}

main()
{
    test -n "$BASHRC_MAIN_SOURCED" && \
        return 0

    readonly BASHRC_MAIN_SOURCED='1'

    # Source global definitions
    local global_profile='/etc/profile'
    # `$PROFILEREAD` is OpenSUSE-specific at the time of writing.
    test -z "$PROFILEREAD" -a -f "$global_profile" && \
        source "$global_profile"

    mesg n || true

    export PATH="$(sanitize_path "/home/linuxbrew/.linuxbrew/bin:$PATH")"

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
    test -z "$(echo "$PROMPT_COMMAND" | grep '\bhistory\b')" && \
        export PROMPT_COMMAND="$(echo "history -a; history -n; $PROMPT_COMMAND" \
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
    export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"

    alias brew-cu='brew cu --no-brew-update'
    alias cpan-outdated='cpan-outdated --mirror="$PERLBREW_CPAN_MIRROR"'
    alias egrep='grep -E'
    alias fgrep='grep -F'
    alias git-sh='exec git-sh'
    alias grep='grep --color=auto'
    alias grepp='grep -P'
    alias l.='ls -d .*'
    alias l='ls -CF'
    alias la='ls -A'
    alias ll='ls -alF'
    alias ls='ls --color=auto'
    alias mosh='exec mosh'
    alias ncdu='ncdu --color dark'
    alias podchecker='podchecker -warnings -warnings -warnings'
    alias ssh-copy-id='ssh-copy-id -oPasswordAuthentication=yes'
    alias ssh='exec ssh'
    alias telnet='exec telnet'
    alias tohex="hexdump -ve '1/1 \"%.2x\" '"
    alias tree='tree -I ".git|node_modules"'
    # shellcheck disable=SC2154
    alias unchomp='sed -i -e \$a\\ '

    add_brewed_items_to_env
    unset -f add_brewed_items_to_env

    # pyenv
    # shellcheck disable=SC2154
    test -d "$HOME/.pyenv" && \
        source <(pyenv init -)

    # Perlbrew
    test -f "$HOME/perl5/perlbrew/etc/bashrc" && \
        source "$HOME/perl5/perlbrew/etc/bashrc"

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

    # Android
    export PATH="$(sanitize_path "$HOME/Android/Sdk/platform-tools:$PATH")"

    # User-installed tools
    export CLASSPATH="$(sanitize_path "$HOME/jar:$HOME/.local/jar:$CLASSPATH")"
    export MANPATH="$(sanitize_path "$HOME/man:$HOME/.local/share/man:$MANPATH")"
    export PATH="$(sanitize_path "$HOME/bin:$HOME/.local/bin:$PATH")"
    export PERL5LIB="$(sanitize_path "$HOME/lib/perl5:$HOME/.local/lib/perl5:$PERL5LIB")"

    # Colours for `tree`
    source <(dircolors -b)

    return 0
}

# Invoke `main` & cleanup
main
unset -f main
