defmodule ReportForge.IdentityTest do
  use ReportForge.Case, async: false

  alias ReportForge.Fixtures
  alias ReportForge.Identity

  test "registers an organization and authenticates its bootstrap api key" do
    %{organization: organization, bootstrap_api_key: token} = Fixtures.organization_fixture()

    assert organization.slug =~ "ledger-corp-"
    assert {:ok, authenticated_organization, _api_key} = Identity.authenticate_api_key(token)
    assert authenticated_organization.id == organization.id
  end

  test "rejects duplicate organization slugs" do
    Fixtures.organization_fixture(%{"slug" => "same-slug"})

    assert {:error, {:conflict, "organization slug already exists"}} =
             Identity.register_organization(%{
               "name" => "Another org",
               "slug" => "same-slug",
               "retention_days" => 20
             })
  end

  test "issues, lists, and revokes organization api keys" do
    %{organization: organization, bootstrap_api_key: bootstrap_token} =
      Fixtures.organization_fixture()

    assert {:ok, %{api_key: api_key, token: issued_token}} =
             Identity.issue_api_key(organization, %{"name" => "analytics"})

    assert issued_token =~ "rfk_"

    assert Enum.any?(Identity.list_api_keys(organization), &(&1.id == api_key.id))

    assert {:ok, revoked_key} = Identity.revoke_api_key(organization, api_key.id)
    assert not is_nil(revoked_key.revoked_at)

    assert {:error, :unauthorized} = Identity.authenticate_api_key(issued_token)
    assert {:ok, _organization, _api_key} = Identity.authenticate_api_key(bootstrap_token)
  end
end
