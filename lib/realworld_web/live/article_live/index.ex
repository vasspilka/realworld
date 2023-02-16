defmodule RealworldWeb.ArticleLive.Index do
  use RealworldWeb, :live_view

  import RealworldWeb.ArticleLive.Actions, only: [actions: 1]

  alias Realworld.Articles
  alias Realworld.Articles.Article
  alias Realworld.Profiles

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      Ash.set_actor(socket.assigns[:current_user])
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, %{"slug" => slug}) do
    case get_article_by_slug(slug) do
      {:ok, article} ->
        socket
        |> assign(:article, article)
        |> assign(:is_owner, is_owner?(socket.assigns[:current_user], article.user))
        |> assign(:following, follows(socket.assigns[:current_user], article.user))

      _ ->
        redirect(socket, to: Routes.page_index_path(socket, :index))
    end
  end

  @impl true
  def handle_event("delete-article", _params, socket) do
    socket.assigns.article
    |> Ash.Changeset.for_destroy(:destroy)
    |> Articles.destroy()

    {:noreply, redirect(socket, to: Routes.page_index_path(socket, :index))}
  end

  def handle_event("favorite-article", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "follow-profile",
        _,
        %{assigns: %{current_user: current_user, article: %{user: user}}} = socket
      ) do
    case Profiles.Follow.create_following(current_user.id, user.id) do
      {:ok, follow} ->
        {:noreply, assign(socket, following: follow)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "unfollow-profile",
        _,
        %{assigns: %{current_user: _current_user, following: following}} = socket
      ) do
    case Profiles.destroy(following) do
      :ok ->
        {:noreply, assign(socket, following: nil)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("follow-profile", _, socket) do
    {:noreply, redirect(socket, to: Routes.auth_path(socket, {:user, :password, :sign_in}))}
  end

  def handle_event("unfollow-profile", _, socket) do
    {:noreply, redirect(socket, to: Routes.auth_path(socket, {:user, :password, :sign_in}))}
  end

  defp get_article_by_slug(slug) do
    slug |> Article.get_by_slug() |> Realworld.Articles.load([:user, :tags])
  end

  defp is_owner?(nil, _), do: false
  defp is_owner?(current_user, user), do: current_user.id == user.id

  defp follows(_current_user = nil, _user), do: nil

  defp follows(current_user, user) do
    case Profiles.Follow.following?(current_user.id, user.id) do
      {:ok, follow} ->
        follow

      _ ->
        nil
    end
  end
end