from __future__ import annotations

from pathlib import Path
from typing import Optional
import xml.etree.ElementTree as ET


class XmlError(Exception):
    pass


def _indent(elem: ET.Element, level: int = 0) -> None:
    i = "\n" + level * "  "
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = i + "  "
        for child in elem:
            _indent(child, level + 1)
        if not elem[-1].tail or not elem[-1].tail.strip():
            elem[-1].tail = i
    if level and (not elem.tail or not elem.tail.strip()):
        elem.tail = i


def read_mods_override(xml_path: Path) -> Optional[str]:
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except ET.ParseError as exc:
        raise XmlError(f"Ошибка чтения XML: {exc}") from exc
    node = root.find("modsDirectoryOverride")
    if node is None:
        return None
    return node.attrib.get("directory")


def upsert_mods_override(xml_path: Path, mods_path: str) -> None:
    try:
        tree = ET.parse(xml_path)
        root = tree.getroot()
    except ET.ParseError as exc:
        raise XmlError(f"Ошибка чтения XML: {exc}") from exc

    tags = root.findall("modsDirectoryOverride")
    target: ET.Element
    if tags:
        target = tags[0]
        for extra in tags[1:]:
            root.remove(extra)
    else:
        target = ET.SubElement(root, "modsDirectoryOverride")

    target.set("active", "true")
    target.set("directory", mods_path)

    _indent(root)
    tree.write(xml_path, encoding="utf-8", xml_declaration=True)

    applied = read_mods_override(xml_path)
    if applied != mods_path:
        raise XmlError("Проверка после записи не прошла: путь в XML не совпадает")
