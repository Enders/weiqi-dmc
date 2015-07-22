defmodule WeiqiDMC.Player.MCRave.Worker do
  def compute do
    receive do
      {:compute, supervisor, mc_rave_state_agent, state} ->
        mc_rave_state = Agent.get(mc_rave_state_agent, &(&1))
        result = WeiqiDMC.Player.MCRave.simulate state, mc_rave_state
        send supervisor, {:computed, self, result}
        compute
      received ->
        IO.inspect {:worker, self, :received_unknown, received}
        compute
    end
  end
end