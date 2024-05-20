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
        {:ok, %MyXQL.Result{rows: rows}} =
          MyXQL.query(:myxql, "SELECT password, plan FROM user WHERE username = ?", [username])

        row =
          case rows do
            [user] -> upsert_row_into_cache_value([Enum.at(user, 0), Enum.at(user, 1)], nil)
            [] -> nil
          end

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

  def update_user_cache() do
    {:ok, %MyXQL.Result{rows: rows}} =
      MyXQL.query(:myxql, "SELECT username, password, plan FROM user")

    prevs = GenServer.call(__MODULE__, :get_all)

    GenServer.cast(
      __MODULE__,
      {:put_all,
       rows
       |> Enum.map(
         &{Enum.at(&1, 0),
          upsert_row_into_cache_value(
            [Enum.at(&1, 1), Enum.at(&1, 2)],
            Map.get(prevs, Enum.at(&1, 0))
          )}
       )
       |> Map.new()}
    )
  end

  # temporary solution until we have everything in the db
  defp upsert_row_into_cache_value([password, plan], prev) do
    %{
      password: password,
      access:
        if prev == nil do
          Map.new()
        else
          premium = plan == "regular"
          Map.put(prev.access, "premium_forum", premium)
        end
    }
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

  @impl true
  def handle_cast({:put_all, data}, _state),
    do: {:noreply, data}
end
