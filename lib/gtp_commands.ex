defmodule WeiqiDMC.GTPCommands do

  alias WeiqiDMC.Board, as: Board

  @gtp_commands [:version, :name, :protocol_version, :list_commands, :quit,
                 :known_command, :boardsize, :clear_board, :komi, :fixed_handicap,
                 :play, :genmove, :showboard, :set_game]

  def process(["version"], _) do
    {:ok, "1.0"}
  end

  def process(["name"], _) do
    {:ok, "elixir-gtp"}
  end

  def process(["protocol_version"], _) do
    {:ok, "2"}
  end

  def process(["set_game", "Go"], _) do
    {:ok, "ok"}
  end

  def process(["known_command", command], _) do
    {:ok, Enum.member?(@gtp_commands, String.to_atom(command)) && "true" || "false"}
  end

  def process(["list_commands"], _) do
    {:ok,  @gtp_commands |> Enum.join " " }
  end

  def process(["boardsize", size], board) do
    try do
      case Board.change_size(board, String.to_integer(size)) do
        :ko -> {:ko, "unacceptable size"}
          _ -> {:ok, ""}
      end
    rescue
      _ in ArgumentError -> {:ko, "invalid board size value"}
    end
  end

  def process(["komi", komi], board) do
    try do
      {:ok, Board.change_komi(board, String.to_float(komi))}
    rescue
      _ in ArgumentError -> {:ko, "invalid komi value"}
    end
  end

  def process(["fixed_handicap", handicap], board) do
    try do
      case Board.set_handicap(board, String.to_integer(handicap)) do
        :ko -> {:ko, "invalid handicap"}
          _ -> {:ok, ""}
      end
    rescue
      _ in ArgumentError -> {:ko, "invalid handicap value"}
    end
  end

  def process(["clear_board"], board) do
    {:ok, Board.clear_board(board)}
  end

  def process(["showboard"], board) do
    {:ok, Board.showboard(board)}
  end

  def process(["play", color, coordinate], board) do
    case Board.play_move(board, coordinate, color) do
      :ko -> {:ko, "illegal move"}
        _ -> {:ok, ""}
    end
  end

  def process(["genmove", color], board) do
    case Board.generate_move(board, color) do
      :ko  -> {:ko, "illegal move"}
      move -> {:ok, move}
    end
  end

  def process(command, board) when is_binary(command) do
    command |> String.split(" ") |> process(board) |> prepare_output
  end

  def process(_, _) do
    {:ko, "not implemented"}
  end

  def prepare_output({:ok, output}) do
    "= #{output}\n\n"
  end

  def prepare_output({:ko, output}) do
    "? #{output}\n\n"
  end
end