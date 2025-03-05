# defmodule Plausible.Session.Transition do
#   @moduledoc """
#   Transitions sessions between deployments.
#   """

#   require Logger

#   def start_link(opts) do
#     :proc_lib.spawn_link(__MODULE__, :loop, [opts])
#   end

#   @doc false
#   def loop_accept(opts) do
#     case :gen_tcp.accept(listen_socket, 1000) do
#       {:ok, socket} -> handle_transition(socket)
#       {:error, :timeout} -> loop_accept(opts)
#     end
#   end

#   @give_ets "GIVE-ETS"

#   defp handle_transition(socket) do
#     case :gen_tcp.recv(socket, byte_size(@give_ets), 1000) do
#       {:ok, @give_ets} ->
#         Logger.info("Transitioning sessions")
#         path = "./sessions"
#         Plausible.Cache.Adapter.tabs2files(:sessions, path)

#         case :gen_tcp.send(socket, <<byte_size(path)::64-unsigned-little, path::binary>>) do
#           :ok -> :gen_tcp.close(socket)
#           {:error, :closed} -> :ok
#         end

#       {:error, :timeout} ->
#         :ok
#     end
#   end
# end
