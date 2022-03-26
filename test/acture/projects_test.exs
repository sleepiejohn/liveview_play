defmodule Acture.ProjectsTest do
  use Acture.DataCase

  alias Acture.Projects

  describe "projects" do
    alias Acture.Projects.Project

    import Acture.ProjectsFixtures

    @invalid_attrs %{customer: nil, description: nil, estimated_completion_at: nil, started_at: nil, status: nil, title: nil}

    test "list_projects/0 returns all projects" do
      project = project_fixture()
      assert Projects.list_projects() == [project]
    end

    test "get_project!/1 returns the project with given id" do
      project = project_fixture()
      assert Projects.get_project!(project.id) == project
    end

    test "create_project/1 with valid data creates a project" do
      valid_attrs = %{customer: "some customer", description: "some description", estimated_completion_at: ~D[2022-03-24], started_at: ~D[2022-03-24], status: :ongoing, title: "some title"}

      assert {:ok, %Project{} = project} = Projects.create_project(valid_attrs)
      assert project.customer == "some customer"
      assert project.description == "some description"
      assert project.estimated_completion_at == ~D[2022-03-24]
      assert project.started_at == ~D[2022-03-24]
      assert project.status == :ongoing
      assert project.title == "some title"
    end

    test "create_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project" do
      project = project_fixture()
      update_attrs = %{customer: "some updated customer", description: "some updated description", estimated_completion_at: ~D[2022-03-25], started_at: ~D[2022-03-25], status: :halted, title: "some updated title"}

      assert {:ok, %Project{} = project} = Projects.update_project(project, update_attrs)
      assert project.customer == "some updated customer"
      assert project.description == "some updated description"
      assert project.estimated_completion_at == ~D[2022-03-25]
      assert project.started_at == ~D[2022-03-25]
      assert project.status == :halted
      assert project.title == "some updated title"
    end

    test "update_project/2 with invalid data returns error changeset" do
      project = project_fixture()
      assert {:error, %Ecto.Changeset{}} = Projects.update_project(project, @invalid_attrs)
      assert project == Projects.get_project!(project.id)
    end

    test "delete_project/1 deletes the project" do
      project = project_fixture()
      assert {:ok, %Project{}} = Projects.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(project.id) end
    end

    test "change_project/1 returns a project changeset" do
      project = project_fixture()
      assert %Ecto.Changeset{} = Projects.change_project(project)
    end
  end
end
