import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list

pub type Value(a) {
  Null
  Int(Int)
  Custom(a)
  Bool(Bool)
  Float(Float)
  String(String)
  Array(List(Value(a)))
  Object(dict.Dict(String, Value(a)))
}

pub fn parse(json: String, using custom_decoders: List(decode.Decoder(a))) {
  json.parse(json, revursive_decoder(custom_decoders))
}

pub fn parse_object(
  json: String,
  using custom_decoders: List(decode.Decoder(a)),
) {
  json.parse(
    json,
    decode.dict(decode.string, revursive_decoder(custom_decoders))
      |> decode.map(Object),
  )
}

pub fn revursive_decoder(
  custom: List(decode.Decoder(a)),
) -> decode.Decoder(Value(a)) {
  decode.recursive(fn() -> decode.Decoder(Value(a)) {
    let wrapped_custom = list.map(custom, fn(dec) { decode.map(dec, Custom) })

    let int_d = decode.int |> decode.map(Int)
    let bool_d = decode.bool |> decode.map(Bool)
    let float_d = decode.float |> decode.map(Float)
    let string_d = decode.string |> decode.map(String)

    let array_d =
      decode.list(revursive_decoder(custom))
      |> decode.map(Array)

    let object_d =
      decode.dict(decode.string, revursive_decoder(custom))
      |> decode.map(Object)

    let null_d =
      decode.new_primitive_decoder("Null", fn(data) {
        case dynamic.classify(data) {
          "Nil" -> Ok(Null)
          _ -> Error(Null)
        }
      })

    let all =
      list.append(wrapped_custom, [
        int_d,
        bool_d,
        float_d,
        string_d,
        array_d,
        object_d,
        null_d,
      ])

    case all {
      [] -> decode.failure(Null, "Value")
      [first, ..rest] -> decode.one_of(first, or: rest)
    }
  })
}
