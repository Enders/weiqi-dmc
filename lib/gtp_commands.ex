defmodule WeiqiDMC.GTPCommands do

  alias WeiqiDMC.Helpers
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  @gtp_commands [:version, :name, :protocol_version, :list_commands, :quit,
                 :known_command, :boardsize, :clear_board, :komi, :fixed_handicap,
                 :play, :genmove, :showboard, :set_game]

  def start_link do
    Agent.start_link fn -> State.empty_board(19) end
  end

  def state(state_agent) do
    Agent.get(state_agent, &(&1))
  end

  def process(["version"], _) do
    {:ok, "1.0"}
  end

  def process(["name"], _) do
    {:ok, "weiqi-dmc"}
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

  def process(["boardsize", size], state_agent) do
    try do
      case Board.change_size(state(state_agent), String.to_integer(size)) do
        :ko -> {:ko, "unacceptable size"}
        state ->
          Agent.update state_agent, fn _ -> state end
          {:ok, ""}
      end
    rescue
      _ in ArgumentError -> {:ko, "invalid board size value"}
    end
  end

  def process(["showboard"], state_agent) do
    {:ok, WeiqiDMC.Board.State.to_string(state(state_agent))}
  end

  def process(["clear_board"], state_agent) do
    state = Board.clear_board state(state_agent)
    Agent.update state_agent, fn _ -> state end
    {:ok, ""}
  end

  def process(["komi", komi], state_agent) do
    try do
      state = Board.change_komi state(state_agent), String.to_float(komi)
      Agent.update state_agent, fn _ -> state end
      {:ok, ""}
    rescue
      _ in ArgumentError -> {:ko, "invalid komi value"}
    end
  end

  def process(["fixed_handicap", handicap], state_agent) do
    try do
      case Board.set_handicap(state(state_agent), String.to_integer(handicap)) do
        {:ko, _} ->
          {:ko, "invalid handicap"}
        {:ok, state} ->
          Agent.update state_agent, fn _ -> state end
          {:ok, ""}
      end
    rescue
      _ in ArgumentError -> {:ko, "invalid handicap value"}
    end
  end

  def process(["play", color, coordinate], state_agent) do
    state = state(state_agent) |> Board.force_next_player(color)
    coordinate = Helpers.coordinate_string_to_tuple(coordinate)
    case Board.compute_move(state, coordinate) do
      {:ok, state} ->
        Agent.update state_agent, fn _ -> state end
        {:ok, ""}
      {:ko, _ }    ->  {:ko, "illegal move"}
    end
  end

  def process(["genmove", color], state_agent) do
    state = state(state_agent) |> Board.force_next_player(color)
    case WeiqiDMC.Player.MCRave.generate_move(state, 20000) do
      :ko     -> {:ko, "illegal state"}
      :resign -> {:ok, "resign"}
      :pass   ->
        {:ok, state} = Board.compute_move(state, :pass)
        Agent.update state_agent, fn _ -> state end
        {:ok, "pass"}
      {row, column} ->
        {:ok, state} = Board.compute_move(state, {row, column})
        Agent.update state_agent, fn _ -> state end
        {:ok, Helpers.coordinate_tuple_to_string({row, column})}
    end
  end

  def process(command, state_agent) when is_binary(command) do
    command |> String.split(" ") |> process(state_agent) |> prepare_output
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