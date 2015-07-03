defmodule Weiqi do
  alias Weiqi.GTPCommands, as: GTPCommand

  def command_loop do
    case IO.gets("") |> String.strip do
      "quit" ->
        IO.binwrite "= bye\n\n"
      command ->
        command |> GTPCommand.process
                |> log_and_return(command)
                |> IO.binwrite
        command_loop
    end
  end

  def log_and_return(output, command) do
    {:ok, file} = File.open "gtp.log", [:append]
    IO.write file, "#{command} -> #{output} \n"
    File.close file
    output
  end

  def start_gtp_server do
    command_loop
  end
end