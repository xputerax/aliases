sail () {
    if [[ -f "./vendor/bin/sail" ]]; then
        ./vendor/bin/sail $@
    else
        echo "./vendor/bin/sail not available, exiting..."
    fi
}
