defmodule WeiqiDMC.GTPCommandsTest do
  use ExUnit.Case

  alias WeiqiDMC.GTPCommands
  alias WeiqiDMC.Board

  doctest WeiqiDMC.GTPCommands

  setup do
    {:ok, state_agent} = GTPCommands.start_link
    Board.change_size state_agent, 9
    {:ok, state_agent: state_agent}
  end

  test "#name", %{state_agent: state_agent} do
    assert GTPCommands.process("name", state_agent) == "= weiqi-dmc\n\n"
  end
end