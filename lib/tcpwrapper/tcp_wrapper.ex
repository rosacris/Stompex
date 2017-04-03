defmodule TCPWrapper do
  def start() do
    if Application.get_env(:stompex, :socket_module) == :ssl do
      :ssl.start()
    end
  end

  def connect(host, port, opts, timeout) do
    module = Application.get_env(:stompex, :socket_module)
    if module in [:ssl, :gen_tcp] do
      module.connect(host, port, opts, timeout)
    end
  end

  def send(sock, frame) do
    module = Application.get_env(:stompex, :socket_module)
    if module in [:ssl, :gen_tcp] do
      module.send(sock, frame)
    end
  end

  def recv(sock, bytes) do
    module = Application.get_env(:stompex, :socket_module)
    if module in [:ssl, :gen_tcp] do
      module.recv(sock, bytes)
    end
  end
  def recv(sock, bytes, timeout) do
    module = Application.get_env(:stompex, :socket_module)
    if module in [:ssl, :gen_tcp] do
      module.recv(sock, bytes, timeout)
    end
  end

  def setopts(socket, options) do
    module = Application.get_env(:stompex, :socket_module)
    case module do
      :ssl ->
        :ssl.setopts(socket, options)
      :gen_tcp ->
        :inet.setopts(socket, options)
    end
  end

  def close(sock) do
    module = Application.get_env(:stompex, :socket_module)
    if module in [:ssl, :gen_tcp] do
      module.clock(sock)
    end
  end
end