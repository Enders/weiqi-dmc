defmodule Weiqi.GTPCommands do
  def process(["version"]) do
    {:ok, "1.0"}
  end

  def process(["name"]) do
    {:ok, "elixir-gtp"}
  end

  def process(["protocol_version"]) do
    {:ok, "2"}
  end

  def process(["known_command"]) do
    {:ok, "true"}
  end

  def process(["list_commands"]) do
    {:ok, [:version, :name, :protocol_version, :list_commands, :quit,
     :known_command, :boardsize, :clear_board, :komi, :play,
     :genmove] |> Enum.join " " }
  end

  def process(["boardsize"]) do
    {:ko, "not implemented"}
  end

  def process(["clear_board"]) do
    {:ko, "not implemented"}
  end

  def process(["play"|_]) do
    {:ko, "not implemented"}
  end

  def process(["genmove"|_]) do
    {:ko, "not implemented"}
  end

  def process(command) when is_binary(command) do
    command |> String.split(" ") |> process |> prepare_output
  end

  def process(_) do
    {:ko, "not implemented"}
  end

  def prepare_output({:ok, output}) do
    "= #{output}\n\n"
  end

  def prepare_output({:ko, output}) do
    "? #{output}\n\n"
  end
end