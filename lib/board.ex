defmodule WeiqiDMC.Board do
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Helpers

  import WeiqiDMC.Helpers, only: [surroundings: 2]

  def from_full_board(full_board, size) do
    prep_board_data = full_board
      |> Enum.chunk(size)
      |> Enum.reverse
      |> Enum.with_index
      |> Enum.map(fn({row_data, row}) -> { Enum.with_index(row_data), row} end)

    from_full_board_row State.empty_board(size), prep_board_data
  end

  def from_full_board_row(state, []) do state end
  def from_full_board_row(state, [{row_data, row}|remaining]) do
    from_full_board_row from_full_board_column(state, row, row_data), remaining
  end

  def from_full_board_column(state, _, []) do state end
  def from_full_board_column(state, row, [{value, column}|remaining]) do
    cond do
       Enum.member?([:black, :b, "Black", "black", "B", "b"], value) ->
        {:ok, state} = compute_move(force_next_player(state, :black), {row+1, column+1})
       Enum.member?([:white, :w, "White", "white", "W", "w"], value) ->
        {:ok, state} = compute_move(force_next_player(state, :white), {row+1, column+1})
       true -> #
     end
      from_full_board_column state, row, remaining
  end

  def change_size(_, size) do
    cond do
      Enum.member?([9,13,19], size) -> State.empty_board(size)
      true -> :ko
    end
  end

  def force_opposite_player(state) do
    %{ state | next_player: Helpers.opposite_color(state.next_player) }
  end

  def force_next_player(state, color) do
     %{ state | next_player: Helpers.normalize_color(color) }
  end

  def clear_board(state) do
    State.empty_board state.size
  end

  def change_komi(state, komi) do
    %{ state | komi: komi }
  end

  def set_handicap(state, handicap) when handicap < 2 or handicap > 9 do
    {:ko, state}
  end

  def set_handicap(state, handicap) do
    handicap_coordinates = Helpers.handicap_coordinates(state.size, handicap) |> Enum.map(&Helpers.coordinate_string_to_tuple(&1))
    compute_moves %{state | handicap: handicap}, handicap_coordinates, :black
  end

  def valid_move?(state, coordinate) do
    case pre_compute_valid_move(state, coordinate, false) do
      {:ko, _} -> false
      {:ok, _} -> true
    end
  end

  def compute_moves(state, [], _) do
    {:ok, state}
  end

  def compute_moves(state, [coordinate|rest], color) do
    case compute_move((state |> force_next_player(color)), coordinate) do
      {:ok, state} -> compute_moves state, rest, color
      {:ko, _ }    -> {:ko, state }
    end
  end

  def compute_move(state, coordinate, color) do
    compute_move (state |> force_next_player(color)), coordinate
  end

  def compute_move(state, :pass) do
    state = (remove_ko(state, state.coordinate_ko) |> force_opposite_player)
    {:ok,  %{ state | moves: state.moves + 1,
                      last_move: :pass,
                      consecutive_pass: state.last_move == :pass } }
  end

  def compute_move(state, coordinate) do
    if State.board_value(state, coordinate) != :empty do
      {:ko, state}
    else
      case pre_compute_valid_move(state, coordinate, true) do
        {:ko, _} -> {:ko, state}
        {:ok, precomputed} -> compute_valid_move state, coordinate, precomputed
      end
    end
  end

  def pre_compute_valid_move(state, coordinate, return_pre_computed) do
    color          = state.next_player
    opposite_color = Helpers.opposite_color(color)
    coordinate_set = Set.put(HashSet.new, coordinate)
    surroundings   = surroundings coordinate, state.size
    empty          = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state, surrounding) == :empty end)
    other_player   = surroundings |> Enum.filter_map(&State.board_has_value?(state, &1, opposite_color),
                                                     &group_containing(&1, opposite_color, state.groups))

    if length(empty) == 0 do
      capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
        liberties == coordinate_set
      end)
      if length(capturing) == 0 do
        same_player = surroundings |> Enum.filter_map(&State.board_has_value?(state, &1, color),
                                                      &group_containing(&1, color, state.groups))

        liberties_same_player_group = Enum.map(same_player, fn ({_, _, liberties}) ->
          Set.size(liberties) - (if Set.member?(liberties, coordinate) do 1 else 0 end)
        end) |> Enum.sum

        if liberties_same_player_group < 1 do
          {:ko, nil}
        else
          if return_pre_computed do
            capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
              liberties == coordinate_set
            end)
            {:ok, {color, empty, Enum.uniq(capturing)}}
          else
            {:ok, nil}
          end
        end
      else
        if return_pre_computed do
          {:ok, {color, empty, Enum.uniq(capturing)}}
        else
          {:ok, nil}
        end
      end
    else
      if return_pre_computed do
        capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
          liberties == coordinate_set
        end)
        {:ok, {color, empty, Enum.uniq(capturing)}}
      else
        {:ok, nil}
      end
    end
  end

  def compute_valid_move(state, coordinate, {color, empty, capturing}) do
    state             = process_move(state, coordinate, color, empty)
    {state, captured} = process_capture(state, capturing, 0)

    state = remove_ko state, state.coordinate_ko

    if captured == 1 do
      possible_ko_coordinate = capturing |> List.first |> elem(1) |> Set.to_list |> List.first
      ko_surroundings = Enum.into surroundings(possible_ko_coordinate, state.size), HashSet.new
      groups_around_ko_in_atari = state.groups |> Enum.filter(fn({_, coordinates, liberties}) ->
        coordinates = Set.to_list coordinates
        liberties   = Set.to_list liberties
        Set.member?(ko_surroundings, List.first(coordinates)) and
        length(coordinates) == 1 and
        liberties == [possible_ko_coordinate]
      end)

      if length(groups_around_ko_in_atari) == 1 do
        coordinate_ko = possible_ko_coordinate
        state = State.update_board state, coordinate_ko, :ko
      end
    else
      coordinate_ko = nil
    end

    {:ok,  %{state | moves: state.moves + 1,
                     consecutive_pass: false,
                     last_move: coordinate,
                     next_player: Helpers.opposite_color(color),
                     coordinate_ko: coordinate_ko,
                     captured_white: state.captured_white + (if color == :black do captured else 0 end),
                     captured_black: state.captured_black + (if color == :white do captured else 0 end) } }
  end

  def remove_ko(state, nil) do state end
  def remove_ko(state, coordinate_ko) do
    State.update_board state, coordinate_ko, :empty
  end

  def group_containing(coordinate, color, groups) do
    Enum.find groups, fn ({group_color, coordinates, _}) ->
      color == group_color and Set.member?(coordinates, coordinate)
    end
  end

  def process_move(state, coordinate, color, move_liberties) do
    opposite_color = Helpers.opposite_color(color)

    {groups, to_merge} = Enum.partition(state.groups, fn {group_color, _, liberties} ->
      #For same group color, find all the groups that have this move as liberty
      #and put them in a list to be merged.
      !(group_color == color and Set.member?(liberties, coordinate))
    end)

    groups = Enum.map(groups, fn {group_color, coordinates, liberties} ->
      #Remove the move in the list of liberties for opposite color groups
      if group_color == opposite_color do
        {group_color, coordinates, Set.delete(liberties, coordinate)}
      else
        {group_color, coordinates, liberties}
      end
    end)

    if !Enum.empty?(to_merge) do
      coordinates = to_merge |> Enum.map(fn ({_, coordinates, _}) -> coordinates end)
                             |> Enum.reduce(fn (liberties, acc) -> Set.union(acc, liberties) end)
      liberties   = to_merge |> Enum.map(fn ({_, _, liberties}) -> liberties end)
                             |> Enum.reduce(fn (liberties, acc) -> Set.union(acc, liberties) end)

      merged = {color, Set.put(coordinates, coordinate), Set.delete(Enum.into(move_liberties, liberties), coordinate)}

      groups = [merged|groups]
    else
      groups = [{color, Set.put(HashSet.new, coordinate), Enum.into(move_liberties, HashSet.new)}|groups]
    end

    %{ State.update_board(state, coordinate, color) | groups: groups}
  end

  def process_capture(state, [], captured) do
    {state, captured}
  end

  def process_capture(state, [{_, coordinates, _}|rest], captured) do
    state = process_capture_group(state, Set.to_list(coordinates))
    process_capture state, rest, captured + Set.size(coordinates)
  end

  def process_capture_group(state, []) do
    state
  end

  def process_capture_group(state, [capture|rest]) do
    surroundings = surroundings(capture, state.size)

    groups = state.groups |> Enum.filter_map(fn {_, coordinates, _} ->
        #Remove all the groups containing the removed stone
        !Set.member?(coordinates, capture)
      end, fn {color, coordinates, liberties} ->
        #Add liberties to the surrounding groups
        if Enum.any?(surroundings, fn surrounding -> Set.member?(coordinates, surrounding) end) do
          {color, coordinates, Set.put(liberties, capture)}
        else
          {color, coordinates, liberties}
        end
      end)

    process_capture_group %{ State.update_board(state, capture, :empty) | groups: groups}, rest
  end
end