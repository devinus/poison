# Upgrading

## v3.0.0
If you depended on the format of `message` in `Poison.Syntax`, it has changed to include the position of the failure.

If returns from `Poison.Parser.parse` have changed.

| < 3.0.0                       | >= 3.0.0                                |
|-------------------------------|-----------------------------------------|
| `{:error, :invalid}`          | `{:error, :invalid, position}`          |
| `{:error, {:invalid, token}}` | `{:error, {:invalid, token, position}}` |


