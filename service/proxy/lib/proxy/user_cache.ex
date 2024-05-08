defmodule Proxy.UserCache do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  # client functions

  def get_user(username, password) do
    maybe_user = GenServer.call(__MODULE__, {:get, username})

    user =
      if maybe_user == nil do
        # TODO: get user from DB
        row =
          if username == "alice",
            do: nil,
            else: %{
              password: "hunter1",
              access:
                if(username == "unreal",
                  do: :premium,
                  else: {:regular, ["hunter"]}
                )
            }

        if row == nil do
          nil
        else
          GenServer.cast(__MODULE__, {:put, username, row})
          row
        end
      else
        maybe_user
      end

    if user == nil or password != user.password do
      nil
    else
      user.access
    end
  end

  # GenServer impls

  @impl true
  def init(:ok),
    do: {:ok, %{}}

  @impl true
  def handle_call({:get, username}, _from, state),
    do: {:reply, Map.get(state, username), state}

  @impl true
  def handle_call(:get_all, _from, state),
    do: {:reply, state, state}

  @impl true
  def handle_cast({:put, username, data}, state),
    do: {:noreply, Map.put(state, username, data)}
end
