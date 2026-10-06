from schema.json import J_BOOL, J_NUM, J_STR, parse_json


def main() raises:
    var raw = String('{"id":1,"name":"a","ok":true,"items":[1,2]}').as_bytes()
    var doc = parse_json(raw)
    var name = doc.find(doc.root, "name")
    if doc.kind(name) != J_STR or doc.text(name) != "a":
        raise Error("name")
    var id = doc.find(doc.root, "id")
    if doc.kind(id) != J_NUM or doc.text(id) != "1":
        raise Error("id")
    var ok = doc.find(doc.root, "ok")
    if doc.kind(ok) != J_BOOL or not doc.boolean(ok):
        raise Error("bool")
    var items = doc.find(doc.root, "items")
    if doc.count(items) != 2 or doc.text(doc.child(items, 1)) != "2":
        raise Error("arr")
    print("ok")
