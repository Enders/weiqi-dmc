defmodule WeiqiDMC.Board do
  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Helpers

  def change_size(_, size) do
    cond do
      Enum.member?([9,13,19], size) ->
        %State{ board: State.empty_board(size), size:  size }
      true -> :ko
    end
  end

  def force_next_player(state, color) do
     %{ state | next_player: Helpers.normalize_color(color) }
  end

  def clear_board(state, size) do
    %State{ board: State.empty_board(state.size), size:  state.size }
  end

  def change_komi(state, komi) do
    %{ state | komi: komi }
  end

  def set_handicap(state, handicap) when handicap < 2 or handicap > 9 do
    {:ko, state}
  end

  def set_handicap(state, handicap) do
    handicap_coordinates = Helpers.handicap_coordinates(state.size, handicap) |> Enum.map(&Helpers.coordinate_string_to_tuple(&1))
    compute_moves state, handicap_coordinates, :black
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
    {:ok,  %{state | board: remove_ko(state.board, state.coordinate_ko),
                     coordinate_ko: nil,
                     next_player: Helpers.opposite_color(state.next_player) } }
  end

  def compute_move(state, coordinate) do
    if State.board_value(state.board, coordinate) != :empty do
      {:ko, state}
    else
      compute_valid_move state, coordinate
    end
  end

  def compute_valid_move(state, coordinate) do
    color        = state.next_player
    surroundings = surroundings coordinate, state.size

    empty        = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == :empty end)

    other_player = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == Helpers.opposite_color(color) end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    same_player  = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == color end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    liberties_same_player_group = Enum.map(same_player, fn ({_, _, liberties}) ->
        length Enum.filter(liberties, fn (liberty) -> liberty != coordinate end)
      end) |> Enum.sum

    capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
      liberties == [coordinate]
    end)

    cond do
      liberties_same_player_group < 1 and length(empty) == 0 and length(capturing) == 0 ->
        {:ko, state}
      true ->
        {board, groups}           = process_move(state.board, state.groups, coordinate, color, empty)
        {board, groups, captured} = process_capture(board, groups, capturing, 0)

        board = remove_ko board, state.coordinate_ko

        if captured == 1 do
          possible_ko_coordinate = capturing |> List.first |> elem(1) |> List.first
          ko_surroundings = surroundings possible_ko_coordinate, state.size
          groups_around_ko_in_atari = groups |> Enum.filter(fn({_, coordinates, liberties}) ->
            liberties == [possible_ko_coordinate] and (ko_surroundings |> Enum.any?(fn(surrounding) ->
              Enum.member?(coordinates, surrounding)
            end))
          end)
          if length(groups_around_ko_in_atari) == 1 do
            coordinate_ko = possible_ko_coordinate
            board = State.update_board board, coordinate_ko, :ko
          end
        else
          coordinate_ko = nil
        end

        {:ok,  %{state | board: board,
                         groups: groups,
                         next_player: Helpers.opposite_color(color),
                         coordinate_ko: coordinate_ko,
                         captured_white: state.captured_white + (if color == :black do captured else 0 end),
                         captured_black: state.captured_black + (if color == :white do captured else 0 end) } }
    end
  end

  def remove_ko(board, nil) do board end
  def remove_ko(board, coordinate_ko) do
    State.update_board board, coordinate_ko, :empty
  end

  def group_containing(coordinate, groups) do
    Enum.find groups, fn ({_, coordinates, _}) ->
      Enum.member? coordinates, coordinate
    end
  end

  def process_move(board, groups, coordinate, color, move_liberties) do
    #Remove the move in the list of liberties for opposite color groups
    groups = groups |>
      Enum.map(fn ({group_color, coordinates, liberties}) ->
        if group_color == Helpers.opposite_color(color) and Enum.member?(liberties, coordinate) do
            {group_color, coordinates, liberties -- [coordinate]}
        else
          {group_color, coordinates, liberties }
        end
      end)

    #For same group color, find all the groups that have this move as liberty
    #and put them in a list to be merged.
    to_merge = groups |> Enum.filter(fn ({group_color, _, liberties}) ->
      group_color == color and Enum.member?(liberties, coordinate)
    end)

    if !Enum.empty?(to_merge) do
      coordinates = to_merge |> Enum.map(fn ({_, coordinates, _}) -> coordinates end)
                             |> List.flatten
                             |> Enum.uniq
      liberties   = to_merge |> Enum.map(fn ({_, _, liberties}) -> liberties end)
                             |> List.flatten
                             |> Enum.uniq

      merged = {color, [coordinate|coordinates], Enum.uniq((liberties ++ move_liberties) -- [coordinate])}
      groups = (groups -- to_merge) ++ [merged]
    else
      groups = groups ++ [{color, [coordinate], move_liberties}]
    end

    { State.update_board(board, coordinate, color), groups }
  end

  def process_capture(board, groups, [], captured) do
    {board, groups, captured}
  end

  def process_capture(board, groups, [{_, coordinates, _}|rest], captured) do
    {board, groups} = process_capture_group(board, groups, coordinates)
    process_capture board, groups, rest, captured + length(coordinates)
  end

  def process_capture_group(board, groups, []) do
    {board, groups}
  end

  def process_capture_group(board, groups, [capture|rest]) do
    #Remove all the groups containing the removed stone
    groups = groups |> Enum.reject(fn ({_, coordinates, _}) ->
      Enum.member?(coordinates, capture)
    end)

    surroundings = surroundings capture, State.board_size(board)

    #Add liberties to the surrounding groups
    groups = groups |> Enum.map(fn ({color, coordinates, liberties}) ->
      if coordinates -- surroundings != coordinates do
        {color, coordinates, Enum.uniq(liberties ++ [capture])}
      else
        {color, coordinates, liberties}
      end
    end)

    process_capture_group State.update_board(board, capture, :empty), groups, rest
  end

  def valid_move?(state, coordinate) do
    #TODO: make it way faster by not computing the new board
    {result, _} = compute_move(state, coordinate)
    result == :ok
  end

  def contiguous?({row_a, column_a}, coordinate_b) do
    [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.any?(fn({delta_row, delta_column}) ->
        {row_a+delta_row, column_a+delta_column} == coordinate_b
      end)
  end

  defp surroundings(coordinate, size) do
    [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.map(&compute_coordinate_from_delta(&1, coordinate, size))
      |> Enum.filter(fn (surrounding) -> surrounding != :invalid end)
  end

  defp compute_coordinate_from_delta({delta_row, delta_column}, {row, column}, size) do
    cond do
      row+delta_row < 1 or row+delta_row > size             -> :invalid
      column+delta_column < 1 or column+delta_column > size -> :invalid
      true -> {row+delta_row, column+delta_column}
    end
  end
end