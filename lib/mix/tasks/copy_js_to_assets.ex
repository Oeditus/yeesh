defmodule Mix.Tasks.Copy.Js.To.Assets do
  use Mix.Task

  @shortdoc "Copies JS from this library into every assets/js/vendor/ found in the project (monolith + umbrella)"

  @library_name :yeesh
  @source_relative "assets/js/yeesh"

  def run(_) do
    # 1. Source directory inside the dependency
    library_path = Mix.Project.deps_paths()[@library_name]

    unless library_path do
      Mix.raise("Could not find dependency #{@library_name} — is it in your mix.exs deps?")
    end

    source_dir = Path.join(library_path, @source_relative)

    unless File.dir?(source_dir) do
      Mix.shell().error("❌ JS source not found at: #{source_dir}")
      Mix.raise("Make sure your JS files are in #{library_path}/#{@source_relative}")
    end

    # 2. Find ALL valid assets/ folders (monolith + umbrella)
    assets_roots = find_all_assets_roots()

    if assets_roots == [] do
      Mix.raise("No assets/ directory with package.json found in the project.")
    end

    for assets_root <- assets_roots do
      target_dir = Path.join([assets_root, "js", "vendor", to_string(@library_name)])
      File.mkdir_p!(target_dir)

      case File.cp_r(source_dir, target_dir, force: true) do
        {:ok, _} ->
          relative = Path.relative_to(target_dir, assets_root)
          Mix.shell().info("✓ Copied JS from #{@library_name} → #{relative} (in #{Path.basename(assets_root)})")
        {:error, reason} ->
          Mix.shell().error("Failed to copy to #{target_dir}: #{reason}")
      end
    end

    Mix.shell().info("Done. JS is now available in all assets/js/vendor/#{@library_name} folders.")
  end

  # Finds every assets/ that has a package.json (safe for monolith + umbrella)
  defp find_all_assets_roots do
    # Look in two common places:
    # 1. Directly at root (normal Phoenix app)
    # 2. Inside apps/*/ (umbrella)
    patterns = [
      "assets/package.json",           # monolith
      "apps/*/assets/package.json"     # umbrella
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.map(&Path.dirname/1)       # get the assets/ directory itself
    |> Enum.reject(&String.contains?(&1, ["node_modules", "_build", "deps"])) # safety filter
    |> Enum.uniq()
  end
end
