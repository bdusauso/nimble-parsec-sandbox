# Copyright (c) 2019, Bram Verburg
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

defmodule Text.Parser do
  @moduledoc false

  # credo:disable-for-this-file

  # parsec:PlugSignature.Parser

  import NimbleParsec

  defmodule Helpers do
    @moduledoc false

    import NimbleParsec

    # rfc7230

    ### section 3.2.3
    # RWS            = 1*( SP / HTAB )
    #                ; required whitespace
    # OWS            = *( SP / HTAB )
    #                ; optional whitespace
    # BWS            = OWS
    #                ; "bad" whitespace
    def rws(combinator \\ empty()), do: times(combinator, ascii_char([?\s, ?\t]), min: 1)
    def ows(combinator \\ empty()), do: repeat(combinator, ascii_char([?\s, ?\t]))
    def bws(combinator \\ empty()), do: ows(combinator)

    ### section 3.2.6
    # tchar          = "!" / "#" / "$" / "%" / "&" / "'" / "*"
    #                / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
    #                / DIGIT / ALPHA
    #                ; any VCHAR, except delimiters
    # token          = 1*tchar
    # obs-text       = %x80-FF
    # qdtext         = HTAB / SP /%x21 / %x23-5B / %x5D-7E / obs-text
    # quoted-pair = quoted-pair    = "\" ( HTAB / SP / VCHAR / obs-text )
    # quoted-string  = DQUOTE *( qdtext / quoted-pair ) DQUOTE
    def tchar(combinator \\ empty()) do
      ascii_char(
        combinator,
        [?!, ?#, ?$, ?%, ?&, ?', ?*, ?+, ?-, ?., ?^, ?_, ?`, ?|, ?~] ++
          [?0..?9, ?a..?z, ?A..?Z]
      )
    end

    def token(combinator \\ empty()), do: times(combinator, tchar(), min: 1)

    def qdtext(combinator \\ empty()) do
      ascii_char(combinator, [?\t, ?\s, 0x21, 0x23..0x5B, 0x5D..0x7E, 0x80..0xFF])
    end

    def quoted_pair(combinator \\ empty()) do
      combinator
      |> ascii_char([?\\])
      |> ascii_char([?\t, ?\s, 0x21..0x7E, 0x80..0xFF])
    end

    def quoted_string(combinator \\ empty()) do
      combinator
      |> ascii_char([?"])
      |> repeat(choice([qdtext(), quoted_pair()]))
      |> ascii_char([?"])
    end

    ### Based on RFC7235 Appendix C
    # auth-param = token BWS "=" BWS ( token / quoted-string )
    def equals(combinator \\ empty()) do
      combinator
      |> bws()
      |> ascii_char([?=])
      |> bws()
    end

    def comma(combinator \\ empty()) do
      combinator
      |> bws()
      |> ascii_char([?,])
      |> bws()
    end

    def generic_param(combinator \\ empty()) do
      combinator
      |> token()
      |> equals()
      |> choice([token(), quoted_string()])
    end

    def named_param(combinator \\ empty(), name, tag) do
      combinator
      |> ignore(
        string(name)
        |> equals()
      )
      |> tag(choice([token(), quoted_string()]), tag)
    end

    def signature_param(combinator \\ empty()) do
      choice(combinator, [
        named_param("keyId", :key_id),
        named_param("signature", :signature),
        named_param("algorithm", :algorithm),
        named_param("created", :created),
        named_param("expires", :expires),
        named_param("headers", :headers),
        ignore(generic_param())
      ])
    end

    def signature_params(combinator \\ empty()) do
      combinator
      |> optional(signature_param())
      |> repeat(ignore(comma()) |> optional(signature_param()))
    end
  end

  defparsecp(:signature_parser, Helpers.signature_params())

  # parsec:PlugSignature.Parser

  def signature(input) do
    with {:ok, result, "", _, _, _} <- signature_parser(input),
         false <- duplicate_keys?(result) do
      {:ok, Enum.map(result, &unescape/1)}
    else
      _ ->
        {:error, "malformed signature header"}
    end
  end

  defp duplicate_keys?(keyword_list) do
    keys = Keyword.keys(keyword_list)
    unique_keys = Enum.uniq(keys)
    length(keys) != length(unique_keys)
  end

  defp unescape({key, [?" | rest]}) do
    {key, to_string(unescape_value(rest))}
  end

  defp unescape({key, value}) do
    {key, to_string(value)}
  end

  defp unescape_value(value, acc \\ [])

  defp unescape_value([?"], acc), do: Enum.reverse(acc)

  defp unescape_value([?\\, c | rest], acc) do
    unescape_value(rest, [c | acc])
  end

  defp unescape_value([c | rest], acc) do
    unescape_value(rest, [c | acc])
  end
end
