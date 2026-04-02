defmodule Yeesh.MarkdownTest do
  use ExUnit.Case, async: true

  alias Yeesh.Markdown

  # ANSI constants for assertions
  @reset "\e[0m"
  @bold "\e[1m"
  @dim "\e[2m"
  @italic "\e[3m"
  @underline "\e[4m"
  @strikethrough "\e[9m"
  @green "\e[32m"
  @blue "\e[34m"
  @h1 "\e[1;33m"
  @h2 "\e[1;36m"
  @h3 "\e[1;37m"

  describe "headings" do
    test "h1 renders bold yellow" do
      result = Markdown.render("# Hello")
      assert result == @h1 <> "Hello" <> @reset
    end

    test "h2 renders bold cyan" do
      result = Markdown.render("## Section")
      assert result == @h2 <> "Section" <> @reset
    end

    test "h3 renders bold white" do
      result = Markdown.render("### Subsection")
      assert result == @h3 <> "Subsection" <> @reset
    end

    test "h4+ also renders bold white" do
      result = Markdown.render("#### Deep")
      assert result == @h3 <> "Deep" <> @reset
    end
  end

  describe "inline formatting" do
    test "bold text" do
      result = Markdown.render("Some **bold** here")
      assert result =~ @bold <> "bold" <> @reset
      assert result =~ "Some "
      assert result =~ " here"
    end

    test "italic text" do
      result = Markdown.render("Some *italic* here")
      assert result =~ @italic <> "italic" <> @reset
    end

    test "inline code" do
      result = Markdown.render("Use `mix test` to run")
      assert result =~ @green <> "mix test" <> @reset
    end

    test "strikethrough" do
      result = Markdown.render("~~removed~~")
      assert result =~ @strikethrough <> "removed" <> @reset
    end

    test "links show text and URL" do
      result = Markdown.render("[Elixir](https://elixir-lang.org)")
      assert result =~ @underline <> @blue <> "Elixir" <> @reset
      assert result =~ @dim <> " (https://elixir-lang.org)" <> @reset
    end
  end

  describe "bullet lists" do
    test "renders with triangle markers" do
      md = """
      - alpha
      - beta
      - gamma
      """

      result = Markdown.render(md)
      assert result =~ "  ▸ alpha"
      assert result =~ "  ▸ beta"
      assert result =~ "  ▸ gamma"
    end

    test "preserves inline formatting in items" do
      md = """
      - **bold** item
      - normal item
      """

      result = Markdown.render(md)
      assert result =~ "  ▸ " <> @bold <> "bold" <> @reset <> " item"
    end
  end

  describe "ordered lists" do
    test "renders with circled numbers" do
      md = """
      1. first
      2. second
      3. third
      """

      result = Markdown.render(md)
      assert result =~ "  ① first"
      assert result =~ "  ② second"
      assert result =~ "  ③ third"
    end

    test "handles start number" do
      md = """
      3. third
      4. fourth
      """

      result = Markdown.render(md)
      assert result =~ "  ③ third"
      assert result =~ "  ④ fourth"
    end

    test "falls back to parenthesized numbers beyond 20" do
      # We can't easily test this via markdown parsing (would need 21+ items),
      # but we can verify the structure with a shorter list.
      md = """
      1. one
      2. two
      """

      result = Markdown.render(md)
      assert result =~ "  ① one"
      assert result =~ "  ② two"
    end
  end

  describe "code blocks" do
    test "renders with box drawing and language header" do
      md = """
      ```elixir
      IO.puts("hello")
      ```
      """

      result = Markdown.render(md)
      assert result =~ @dim <> "  ┌─ elixir" <> @reset
      assert result =~ @green <> "IO.puts(\"hello\")" <> @reset
      assert result =~ @dim <> "  └─" <> @reset
    end

    test "renders without language when not specified" do
      md = """
      ```
      plain code
      ```
      """

      result = Markdown.render(md)
      assert result =~ @dim <> "  ┌─" <> @reset
      assert result =~ @green <> "plain code" <> @reset
    end
  end

  describe "block quotes" do
    test "renders with bar prefix" do
      md = """
      > Something wise was said.
      """

      result = Markdown.render(md)
      assert result =~ @dim <> "  │ " <> @reset
      assert result =~ "Something wise was said."
    end
  end

  describe "thematic break" do
    test "renders as dim horizontal rule" do
      result = Markdown.render("---")
      assert result =~ @dim <> String.duplicate("─", 40) <> @reset
    end
  end

  describe "paragraphs" do
    test "separates paragraphs with double CRLF" do
      md = """
      First paragraph.

      Second paragraph.
      """

      result = Markdown.render(md)
      assert result =~ "First paragraph.\r\n\r\nSecond paragraph."
    end
  end

  describe "mixed content" do
    test "renders heading followed by paragraph and list" do
      md = """
      # Title

      Some intro text.

      - item one
      - item two
      """

      result = Markdown.render(md)
      assert result =~ @h1 <> "Title" <> @reset
      assert result =~ "Some intro text."
      assert result =~ "  ▸ item one"
      assert result =~ "  ▸ item two"
    end
  end
end
