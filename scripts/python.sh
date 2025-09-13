# activate venv
activate() {
    if [ ! -f "./.venv/bin/activate" ]; then
        echo "./.venv/bin/activate not found, exiting"
	else
		. .venv/bin/activate
    fi

}
