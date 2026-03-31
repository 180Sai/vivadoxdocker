# Run Vivado container with VNC port forwarding
# Browser: http://localhost:6080
# VNC Client: localhost:5900

docker run -it `
  --name vivado_env_wsl `
  -p 6080:6080 `
  -p 5900:5900 `
  -v ${PWD}:/home/vivado-guest/workspace `
  vivado:2016.2 `
  /bin/bash -c "sudo /home/vivado-guest/workspace/web_startup.sh"
