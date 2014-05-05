defmodule Dynamo.Connection.Behaviour do
  @moduledoc """
  Common behaviour used between `Dynamo.Connection` connection
  implementations. When used, it defines a module `Connection` 
  containing a struct with the following fields and their default values:

  * assigns - an empty list
  * params - `nil`
  * req_headers - `nil`
  * req_body - `nil`
  * resp_body - an empty binary
  * resp_charset - `"utf-8"`
  * resp_content_type - `nil`
  * resp_cookies - `[]`
  * resp_headers - an empty binary dict
  * state - `:unset`
  * status - `nil`
  * script_name_segments - an empty list

  Besides the fields above, it also defines the following
  fields, but it expects those fields to be set when the
  connection is initialized with the following contents:

  * main - the entry point module for the connection
  * before_send - a call to `Dynamo.Connection.default_before_send`
  * method - the current request method
  * original_method - the current request method
  * path_info_segments - the current path segments

  A developer can pass extra fields via `use`:

      use Dynamo.Connection.Behaviour, [:my_field, :other_field]

  """

  @doc false
  defmacro __using__(opts) do
    fields = [
      assigns: [],
      before_send: [],
      fetchable: [],
      main: nil,
      method: nil,
      original_method: nil,
      params: nil,
      path_info_segments: nil,
      private: [],
      req_body: nil,
      req_cookies: nil,
      req_headers: nil,
      resp_body: "",
      resp_charset: "utf-8",
      resp_cookies: [],
      resp_content_type: nil,
      resp_headers: Binary.Dict.new([{"cache-control", "max-age=0, private, must-revalidate"}]),
      route_params: [],
      state: :unset,
      status: nil,
      script_name_segments: []
    ] ++ opts

    quote location: :keep do
      @behaviour Dynamo.Connection

      defmodule Connection do
        defstruct unquote(fields)

        ## Assigns

        @doc false
        def assigns(%Connection{assigns: assigns}) do
          assigns
        end

        @doc false
        def assign(key, value, %Connection{assigns: assigns} = conn) do
          %Connection{conn | assigns: Keyword.put(assigns, key, value)}
        end

        @doc false
        def put_assign(key, value, conn) do
          assign(key, value, conn)
        end

        @doc false
        def private(%Connection{private: private}) do
          private
        end

        @doc false
        def put_private(key, value, %Connection{private: private} = conn) do
          %Connection{conn | private: Keyword.put(private, key, value)}
        end

        @doc false
        def main(%Connection{main: main}) do
          main
        end

        ## Fetch

        @doc false
        def fetchable(atom, fun, %Connection{fetchable: fetchable} = conn) when is_atom(atom) and is_function(fun, 1) do
          %Connection{conn | fetchable: [{ atom, fun }|fetchable]}
        end

        ## Request

        @doc false
        def params(%Connection{params: nil}) do
          raise Dynamo.Connection.UnfetchedError, aspect: :params
        end

        @doc false
        def params(%Connection{params: params}) do
          params
        end

        @doc false
        def route_params(%Connection{route_params: route_params}) do
          route_params
        end

        @doc false
        def route_params(new, %Connection{params: nil, route_params: route_params} = conn) do
          %Connection{conn | route_params: route_params ++ new}
        end

        @doc false
        def route_params(new, %Connection{params: params, route_params: route_params} = conn) do
          %Connection{conn | route_params: route_params ++ new, params: Dict.merge(params, new)}
        end

        @doc false
        def method(%Connection{method: method}) do
          method
        end

        @doc false
        def method(method, conn) when is_binary(method) do
          %Connection{conn | method: method}
        end

        @doc false
        def req_headers(%Connection{req_headers: nil}) do
          raise Dynamo.Connection.UnfetchedError, aspect: :req_headers
        end

        @doc false
        def req_headers(%Connection{req_headers: req_headers}) do
          req_headers
        end

        @doc false
        def req_body(%Connection{req_body: nil}) do
          raise Dynamo.Connection.UnfetchedError, aspect: :req_body
        end

        @doc false
        def req_body(%Connection{req_body: req_body}) do
          req_body
        end

        ## Cookies

        @doc false
        def req_cookies(%Connection{req_cookies: nil}) do
          raise Dynamo.Connection.UnfetchedError, aspect: :cookies
        end

        @doc false
        def req_cookies(%Connection{req_cookies: req_cookies}) do
          req_cookies
        end

        @doc false
        def resp_cookies(%Connection{resp_cookies: resp_cookies}) do
          resp_cookies
        end

        @doc false
        def put_resp_cookie(key, value, opts, %Connection{resp_cookies: resp_cookies} = conn)
            when is_binary(key) and (is_binary(value) or nil?(value)) and is_list(opts) do
          resp_cookies = List.keydelete(resp_cookies, key, 0)
          %Connection{conn, resp_cookies: [{ key, value, opts }|resp_cookies]}
        end

        ## Paths

        @doc false
        def path_info_segments(%Connection{path_info_segments: segments}) do
          segments
        end

        @doc false
        def path_info(%Connection{path_info_segments: segments}) do
          to_path segments
        end

        @doc false
        def script_name_segments(%Connection{script_name_segments: segments}) do
          segments
        end

        @doc false
        def script_name(%Connection{script_name_segments: segments}) do
          to_path segments
        end

        @doc false
        def forward_to(segments, _target,
            %Connection{path_info_segments: path, script_name_segments: script} = conn) do
          { prefix, ^segments } = Enum.split path, length(path) - length(segments)

          %Connection{conn |
            path_info_segments: segments,
            script_name_segments: script ++ prefix
          }
        end

        defp to_path(segments) do
          "/" <> Enum.join(segments, "/")
        end

        ## Response

        @doc false
        def status(%Connection{status: status}) do
          status
        end

        @doc false
        def status(status, %Connection{state: state} = conn) when
            is_integer(status) and state in [:unset, :set, :sendfile, :chunked] do
          %Connection{conn | status: status, state: :set}
        end

        @doc false
        def resp_body(%Connection{resp_body: resp_body}) do
          resp_body
        end

        @doc false
        def resp_body(body, %Connection{status: status, state: state} = conn) when state in [:unset, :set] do
          %Connection{conn |
            status: status || 200,
            resp_body: body,
            state: :set}
        end

        @doc false
        def resp_content_type(%Connection{resp_content_type: resp_content_type}) do
          resp_content_type
        end

        @doc false
        def resp_content_type(resp_content_type, conn) when is_binary(resp_content_type) do
          %Connection{conn | resp_content_type: resp_content_type}
        end

        @doc false
        def resp_charset(%Connection{resp_charset: resp_charset}) do
          resp_charset
        end

        @doc false
        def resp_charset(resp_charset, conn) when is_binary(resp_charset) do
          %Connection{conn | resp_charset: resp_charset}
        end

        @doc false
        def resp(status, body, %Connection{state: state} = conn)
            when is_integer(status) and state in [:unset, :set] do
          %Connection{conn |
            status: status,
            resp_body: body,
            state: :set
          }
        end

        @doc false
        def send(%Connection{status: status, resp_body: body} = conn) do
          send(status, body, conn)
        end

        @doc false
        def state(%Connection{state: state}) do
          state
        end

        @doc false
        def resp_headers(%Connection{resp_headers: resp_headers}) do
          resp_headers
        end

        @doc false
        def put_resp_header(key, value, %Connection{resp_headers: resp_headers} = conn) do
          %Connection{conn, resp_headers: Binary.Dict.put(resp_headers, key, to_string(value))}
        end

        @doc false
        def delete_resp_header(key, %Connection{resp_headers: resp_headers} = conn) do
          %Connection{conn | resp_headers: Binary.Dict.delete(resp_headers, key)}
        end

        # Callbacks

        @doc false
        def before_send(fun, %Connection{before_send: before_send} = conn) when is_function(fun) do
          %Connection{conn | before_send: [fun|before_send]}
        end

        defp run_before_send(%Connection{before_send: before_send} = conn) do
          Enum.reduce Enum.reverse(before_send), conn, fn(fun, c) -> fun.(c) end
        end
      end
    end

  end
end