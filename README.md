[![Build Status](https://travis-ci.org/manageplaces/Stompex.svg?branch=master)](https://travis-ci.org/manageplaces/Stompex)

# Stompex

This is a forked Stompex library that adds support for SSL connections with the broker. I will try to get it merged with the original Stompex project in the near future.
Stompex is a library to allow you to connect to STOMP based servers. It is a work
in progress, so please expect any future changes to be breaking until v1.0 is release.

## Installation

Until a fully functional version is ready, Stompex will not be published
to hex. As such, installing it requires you to point your dependency at
this repo.

```elixir
def deps do
  [{ :stompex, git: "git@github.com:manageplaces/Stompex.git" }]
end
```

or

```elixir
def deps do
  [{ :stompex, git: "https://github.com/manageplaces/Stomex.git" }]
end
```

Once you've run `mix deps.get`, ensure that `Stompex` is added to your
applications list in `mix.exs`.

```elixir
def application do
  [applications: [:stompex]]
end
```

## Getting started

Stompex requires 3 simple steps to get going:

- Connect
- Register a callback for messages
- Subscribe to a topic

For this, there are 3 functions:

- `connect/4`
- `register_callback/3`
- `subscribe/2`

There are other variations of these functions which we'll get to later, but for
now, these are the ones you need to get going.

Lets look at a simple example:

```elixir
{ :ok, conn } = Stompex.connect("localhost", 12345, "username", "password")

callback = fn (msg) ->
  IO.puts msg
end

Stompex.register_callback conn, "/queue/or/topic/here", callback
Stompex.subscribe conn, "/queue/or/topic/here"
```

And that's it, you should now start seeing messages displayed. Obviously you're
more than likely going to want to do something else with the message, such as
parse JSON, or XML or whatever it is you might be receiving, but you get the idea.

Once you've finished, you can disconnect by simply calling

```elixir
Stompex.disconnect(conn)
```

Nice and easy.

## Advanced usage

Moving on, you may want to do things differently. As mentioned previously, there
are other variations on the functions listed. Lets take a look at some of the
other options you have to interact with Stompex.

### connect

Stompex provides 3 variations of the connect function:

#### `connect/0`

This allows you to configure the connection details using mix configurations.
If you choose to use this option, Stompex will expect the following in your configuration
file:

```elixir
config :stompex,
  host: "host@stompserver.com",
  login: "login",
  port: 12345,
  passcode: "passcode",
  headers: %{}
```

Of these options, only the host is required. If this is all you supply, then the
login and passcode values will be empty strings, and the port will default to
`61613`.

#### `connect/4`

This is the function used in the first example, so there's not much more to explain.
The four arguments expected are simply the `host`, `port`, `login`, and `passcode`.

#### `connect/5`

Exactly the same as `connect/4` with the addition of a headers hash. This may or
may not be required by your server, but anything that your server requires can be
supplied here. Note that anything you add here, will ONLY be used for the connection,
and nothing else. If you need headers for other things, then they should be supplied
later.

### subscribe

#### `subscribe/2`

This is the function used in the first example. Here, we simply
specify the queue or topic that we wish to subscribe to

```elixir
Stompex.subscribe(conn, "/queue/name")
```

#### `subscribe/3`

The same as `subscribe/2`, but options can be supplied. See
`subscribe/4` for available options

#### `subscribe/4`

If the queue/topic you're subscribing to expects headers to be
supplied, then this function should be used. The third argument allows
you to specify a map of headers containing anything you like (that is
valid within the STOMP specification).

The fourth argument allows you to supply options. The options available
are:

- `:compressed` - Whether or not the body of the frame is gzip compressed.
If `false` (which is default), Stompex will simply leave the frames body
as it is, but if set to `true`, it will automatically decompress the body
before passing the frame on.

```elixir
Stompex.subscribe(conn, "/queue/name", %{"header1" => "value 1",
                                         "header2" => "value 2"}
```

### Multiple callbacks

It is possible to register more than one callback for a single queue
or topic. Simply call the `register_callback/3` function as many times
as you see fit. These can be removed at any point (more later) so you
can dynamically adjust where message should be sent.

### Removing a callback

We saw earlier how we can add a calback, however stompex also allows
us to remove a callback. To do this, simply call `remove_callback/3`
with the same arguments as `register_callback/3`.

```elixir
Stompex.remove_callback(conn, "/queue/name", callback)
```

### Acking and Nacking

Some servers may require that you acknowledge messages that you have
received, or you may simply wish to do this yourself. Either way,
Stompex makes this very simple. The first thing you should do, is let
the server know that you will be acknowledging the messages, but
supplying a header when you subscribe to a queue or topic

```elixir
Stompex.subscribe(conn, "/queue/name", %{ "ack" => "client" })
```

Once this has been specified, you are now responsible for
acknowledging receipt of the message in your callback function. To do
this, you can use the `ack/2` function:

```elixir
callback = fn(msg) ->
  Stompex.ack(conn, msg)
  ...
end
```

**Please note:** It is possible for multiple callbacks to be
registered for a single queue or topic, but only one of these should
acknowledge the message.


It is also possible to `NACK` a message if you're connecting to
a STOMP server that supports version 1.1 or above of the STOMP
protocol. This works in exactly the same way as the `ack/2`
function

```elixir
callback = fn(msg) ->
  ...
  cond do
    is_processed?(msg) ->
      Stompex.ack(conn, msg)

    true ->
      Stompex.nack(conn, msg)
  end
end
```

### Without registering callbacks

If you prefer not to work with explicit callback functions, and
instead would rather use Stompex in conjunction with something like a
GenServer, you can instruct Stompex to send all message to the calling
process. If you do this, all messages received on any queue or topic
will be sent to the calling process, where you can handle as you
wish. Below is an example of how this might work.

```elixir
defmodule StompexTest do
  use GenServer

  def start_link() do
    { :ok, pid } = GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    { :ok, conn } = Stompex.connect()

    Stompex.send_to_caller(conn, true)
    Stompex.subscribe(conn, "/queue/name")

    { :ok, %{ stompex: conn } }
  end

  def handle_info({ :stompex, "/queue/name", frame }, %{ stompex: conn } = state) do
    { :noreply, state }
  end

end
 ```

The key here is is the `send_to_caller/2` function. This is the
instruction to Stompex to start sending message to the calling
process, which in this example is a GenServer.

All messages here are then handled by the `handle_info/2` function.

### Sending a message

If you're connecting to a server that is used for two way
communication, Stompex will allow you to easily send frames
back to the server using the `send/3` function:

```elixir
...
msg = """
Hello world!

I'm a multi line message. I can include
any character I like, including #{<<0>>} if
I feel like it!
"""
Stompex.send(conn, "/queue/my-queue", msg)
```

Stompex will automatically set the `content-length` header,
so you are free to add any characters you like to the message.

## That's all folks

So that about sums up Stompex. If you run into any problems along the
way, open an issue. Feel free to open issues to just ask questions.

#### Notes:

Stompex was written initially for an internal application, so it has
only really been tested at this point for that specific use case. As
such, we cannot guarantee that it will work across all versions of
STOMP, or that you won't run into any issues. But then again, that is
why it's still a 0.x release.

- If you find Stompex useful, and use it in an app, we'd love to hear about it!
- If you find an issue and fix it, then send us a pull request, all
  requests are welcomed.
- If you stumble upon a bug, then please make sure you supply enough
  information with the issue for us to figure out what's gone
  wrong. Ideally in the format of
  - Elixir version
  - Data that has failed
  - Anything else necessary to replicate

#### Todo:

There are a number of things missing from Stompex, so here is a brief
list of things that still need to be added.

- Send heartbeats. Stompex is able to receive them, but does not currently send them.
- Support transactions.
- Fully support all STOMP versions. We've only really tested on 1.1.
- Test test test. REALLY need to add some more tests.
- Anything else remaining in the STOMP spec that a decent STOMP
  implementation should have.

#### License

Stompex is released under the MIT license so you're free to use in any
project you desire. If you feel like attributing us that would be
fantastic, but you're not required to.

Have fun :)
