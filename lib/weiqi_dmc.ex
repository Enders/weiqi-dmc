defmodule WeiqiDMC do
  alias WeiqiDMC.GTPCommands, as: GTPCommand

  def command_loop(state_agent) do
    command = IO.gets("")
    if command == :eof do
      command = "quit"
    end
    case command |> String.strip do
      "quit" ->
        IO.binwrite "= bye\n\n"
      command ->
        command |> GTPCommand.process(state_agent)
                |> log_and_return(command)
                |> IO.binwrite
        command_loop state_agent
    end
  end

  def log_and_return(output, command) do
    {:ok, file} = File.open "gtp.log", [:append]
    IO.write file, "#{command} -> #{output} \n"
    File.close file
    output
  end

  def start_gtp_server do
    {:ok, state_agent} = WeiqiDMC.GTPCommands.start_link
    command_loop state_agent
  end
end