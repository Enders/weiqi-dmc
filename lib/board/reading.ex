defmodule WeiqiDMC.Board.Reading do

  alias WeiqiDMC.Board.State
  import WeiqiDMC.Helpers, only: [surroundings: 2, opposite_color: 1]

  def ruin_perfectly_good_eye?(state, coordinate) do
    if Enum.empty?(state.groups) do
      false
    else
      coordinate_set = Set.put(HashSet.new, coordinate)

      #Would this move save from an atari? (it's assumed it's a legal move == not a suicide)
      last_liberty_own_group = Enum.any?(state.groups, fn {color, _, liberties} ->
        color == state.next_player and liberties == coordinate_set
      end)

      !last_liberty_own_group and is_eyeish_for?(state.next_player, state, coordinate)
    end
  end

  def self_atari?(state, coordinate) do
    if Enum.empty?(state.groups) do
      false
    else
      opposite_color = opposite_color(state.next_player)
      coordinate_set = Set.put(HashSet.new, coordinate)

      #Put a largish group in atari without capturing any other group
      #More than 6 stones -> life, so no point putting yourself in atari
      #TODO: make an actual difference between suicide for L&D reason (shape within group) and
      #      just stupid suicide
      Enum.any?(state.groups, fn {color, coordinates, liberties} ->
        color == state.next_player and Set.size(coordinates) > 6 and Set.size(liberties) == 2 and Set.member?(liberties, coordinate)
      end) and !Enum.any?(state.groups, fn {color, _, liberties} ->
        color == opposite_color and liberties == coordinate_set
      end)
    end
  end

  defp is_eyeish_for?(color, state, coordinate) do
    surroundings = surroundings(coordinate, state.size)
    length(surroundings) == length(Enum.filter(surroundings, &State.board_has_value?(state, &1, color)))
  end
end