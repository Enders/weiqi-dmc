defmodule WeiqiDMC do
  alias WeiqiDMC.GTPCommands, as: GTPCommand

  def command_loop(board) do
    case IO.gets("") |> String.strip do
      "quit" ->
        IO.binwrite "= bye\n\n"
      command ->
        command |> GTPCommand.process(board)
                |> log_and_return(command)
                |> IO.binwrite
        command_loop board
    end
  end

  def log_and_return(output, command) do
    {:ok, file} = File.open "gtp.log", [:append]
    IO.write file, "#{command} -> #{output} \n"
    File.close file
    output
  end

  def start_gtp_server do
    {:ok, board} = WeiqiDMC.Board.start_link
    command_loop board
  end
end