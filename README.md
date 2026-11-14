# NoC Router IP

A simple Network-on-Chip (NoC) router, designed from scratch in VHDL (and SystemVerilog for later). This is a learning project: I want to understand how a router works inside, so I build it step by step.

## Why this project

A modern chip has many blocks (CPU, GPU, memory controller, accelerators) that must talk to each other. One shared bus is too slow when there are many blocks, so chips now use a small network inside the chip. This is a NoC.

The router is the main piece of this network. It receives data from a neighbour, decides where it must go, and sends it on.

I start with the simplest choices: a 2D mesh and XY routing. This way I can focus on what happens inside one router before I look at bigger topologies.

## What is in V1

The flit (the piece of data that travels) has 32 bits:

| Bits | Field | Note |
|---|---|---|
| 31 to 30 | flit type | reserved, not used in V1 |
| 29 to 27 | destination X | |
| 26 to 24 | destination Y | |
| 23 to 0 | payload | the router never reads it |

The router has 5 ports: North, South, East, West and Local (the block next to the router). Bit 0 is always on the right, in this order: N, S, E, W, L.

The router is made of these blocks:

* **Input port**: a FIFO that stores the incoming flits, and a route compute block that reads the destination of the first flit.
* **FIFO**: depth 8. The first flit is always visible, so the router can look at it without taking it out.
* **Route compute**: XY routing. The flit goes along X first, then along Y. The result is one output port.
* **Arbiter**: when several inputs want the same output, it picks one. It is round-robin, so nobody waits forever.
* **Switch allocator**: five arbiters, one per output. It also blocks a request when the next router is not ready.
* **Crossbar**: for each output, it copies the flit of the input that won.
* **Router top**: connects everything, and contains the reset synchronizer.

![Router block diagram](docs/images/router_block_diagram.png)

## Simplifications in V1

* One packet is one flit. This way I do not need to cut messages into pieces yet.
* No pipeline. Everything between the FIFO and the output is done in one clock cycle.
* No virtual channels. If the first flit of a FIFO is blocked, the flits behind it wait too.
* Simple valid/ready handshake between routers, not credits.
* No network interface. The testbench sends ready-made flits.
* Flits never go back where they came from. This is true with XY routing, and the testbench respects it.
* Destinations outside the mesh are not handled.
* The reset is synchronized inside the router. For a real network, it will move to the top level.

## What I verified

Each block has a self-checking testbench. It prints PASS or FAIL for each check, and a final message.

| Testbench | What it checks |
|---|---|
| priority encoder | all 16 possible inputs |
| switch allocator | all 20 input/output pairs, blocked outputs, fairness, two conflicts at once, reset |
| port | reset, all directions, full FIFO, pop when empty, flit order, reset during traffic |
| router | all destinations, blocked outputs, full FIFO, fairness, 5 flows at the same time, flit order, head of line blocking, reset during traffic, random traffic where every flit must come out exactly once |

All of these end with `ALL TESTS PASSED`. The router was tested for a 5x5 mesh.

## V2 (planned)

* Packets with several flits (head, body, tail) and wormhole switching
* Credit-based flow control
* Virtual channels
* A pipeline, to reach a higher clock speed
* A small NoC with several routers, with the reset at the top level
* The same design in SystemVerilog, and a UVM testbench
* Timing analysis with constraint files

## Repository

```
rtl/
  vhdl/
    pkg/    package with the constants and types
    core/   FIFO, route compute, port, arbiter, switch allocator, crossbar
    top/    router
  systemverilog/   same structure, coming later
sim/
  vhdl/     all testbenches
  uvm/      empty for now
docs/       detailed documents (V1 now, V2 later)
constraints/  SDC files, for timing analysis later
```

## How to simulate

I used Vivado (xsim).

1. Add all files from `rtl/vhdl` as design sources. The package `router_pkg` must be compiled first.
2. Add the testbench you want from `sim/vhdl` as a simulation source and set it as top.
3. Run the simulation with `run all` in the Tcl console. The default 1000 ns is too short.
4. Look for `ALL TESTS PASSED` at the end of the console.

To test another router position in `tb_router`, change the two constants `X_POS` and `Y_POS`.

## More details

A longer document with the design of each block is in the `docs` folder.

## Author

**Duval MAMBOU**
Electrical Engineering student, FPGA and SoC design
ENIB, National School of Engineering of Brest, France

[LinkedIn](https://www.linkedin.com/in/duval-mambou) | [GitHub](https://github.com/duval-mambou)# Network-on-Chip-Router-WIP
