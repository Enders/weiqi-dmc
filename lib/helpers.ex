defmodule WeiqiDMC.Helpers do

  def handicap_coordinates(size, handicap) do
    case {size, handicap} do
      {19, 2} -> ["D4", "Q16"]
      {19, 3} -> ["D4", "Q16", "D16"]
      {19, 4} -> ["D4", "Q16", "D16", "Q4"]
      {19, 5} -> ["D4", "Q16", "D16", "Q4", "K10"]
      {19, 6} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10"]
      {19, 7} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K10"]
      {19, 8} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K4", "K16"]
      {19, 9} -> ["D4", "Q16", "D16", "Q4", "D10", "Q10", "K4", "K16", "K10"]

      {13, 2} -> ["D4", "K10"]
      {13, 3} -> ["D4", "K10", "D10"]
      {13, 4} -> ["D4", "K10", "D10", "K4"]
      {13, 5} -> ["D4", "K10", "D10", "K4", "G7"]
      {13, 6} -> ["D4", "K10", "D10", "K4", "D7", "K7"]
      {13, 7} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G7"]
      {13, 8} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G10", "G4"]
      {13, 9} -> ["D4", "K10", "D10", "K4", "D7", "K7", "G10", "G4", "G7"]

      { 9, 2} -> ["C3", "G7"]
      { 9, 3} -> ["C3", "G7", "C7"]
      { 9, 4} -> ["C3", "G7", "C7", "G3"]
      { 9, 5} -> ["C3", "G7", "C7", "G3", "E5"]
      { 9, 6} -> ["C3", "G7", "C7", "G3", "C5", "G5"]
      { 9, 7} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E5"]
      { 9, 8} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E7", "E3"]
      { 9, 9} -> ["C3", "G7", "C7", "G3", "C5", "G5", "E7", "E3", "E5"]
    end
  end

  def coordinate_string_to_tuple("pass") do :pass end

  def coordinate_string_to_tuple(coordinate) when is_bitstring(coordinate) do
    normalized_column = coordinate |> String.upcase |> String.to_char_list |> List.first
    row               = String.to_integer String.slice(coordinate, 1,String.length(coordinate)-1)
    column            = Enum.find_index 'ABCDEFGHJKLMNOPQRSTUVWXYZ', fn (column) -> column == normalized_column end
    {row, column+1}
  end

  def coordinate_tuple_to_string(nil) do "none" end
  def coordinate_tuple_to_string(:resign) do "resign" end
  def coordinate_tuple_to_string(:pass) do "pass" end
  def coordinate_tuple_to_string({row, column}) do
    "#{String.at("ABCDEFGHJKLMNOPQRSTUVWXYZ", column-1)}#{row}"
  end

  def opposite_color(:black) do :white end
  def opposite_color(:white) do :black end

  def normalize_color(color) when is_bitstring(color) do
    case color |> String.downcase |> String.first do
      "b" -> :black
      "w" -> :white
    end
  end

  def normalize_color(color) when is_atom(color) do
    color
  end
end