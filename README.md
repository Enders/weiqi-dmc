# WeiqiDMC

WeiqiDMC stands for *Weiqi Distributed Monte Carlo*, just a fancy temporary name because naming it *GoSomething* would have made matters confusing, wouldn't it?

As it stands, the project is just a pet-project made to test out the hypothesis that performance losses in Elixir (compared to C/C++, especially when it comes to memory management) can be offseted by the ease of writing distributed applications. Monte Carlo estimation seems like a good candidate as simulations are mostly independent, and RAVE can be seen as a main controller, spawning the simulations. Looks like a good use case for Elixir!

## Main features

Supported GTP (Go Text Protocol) commands:

`[:version, :name, :protocol_version, :list_commands, :quit,
                 :known_command, :boardsize, :clear_board, :komi, :fixed_handicap,
                 :play, :genmove, :showboard, :set_game]`

Current engine is a Random Player. It has no other purpose than test out the rest of the framework.

## Installation & running

**Installation**

For profiling, you'll need to run `mix deps.get`, there are no other dependencies ATM.

**With GTP front-end**

Many GTP front-end seem particularity finicky with the path to the binary, so I ended-up just writing a simple bash script (chmod +x) and use the path to that script:

    #!/bin/bash
    cd FULL_PATH/TO/PROJECT && FULL_PATH/TO/MIX/BINARY run -e "WeiqiDMC.start_gtp_server"`

I used *Quarry* to test it out.

**The tests**

Same as normal, just `mix test`

## Roadmap

 1. Add time management + pondering (can be done  with the random player, although it's kind of pointless, it'd make things ready for the real meat of this project)
 2. Implement MC + RAVE as a separate player and use Elixir goodies to make it pluggable
 3. Devise a protocol for testing vs other engines
 4. Tune the engine
 5. Glory
 6. Implement Scoring, Position Estimation, etc.
 7. Resign from the project and start a fork to *make things right*

## Contributing

Please do!
