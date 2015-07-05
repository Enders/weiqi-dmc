#!/bin/bash
#This script starts the program, useful when the used GTP front-end only accept a path to a binary

cd /home/ggrenet/projects/elixir/weiqi_dmc && /home/ggrenet/projects/elixir/elixir/bin/mix run -e "WeiqiDMC.start_gtp_server"