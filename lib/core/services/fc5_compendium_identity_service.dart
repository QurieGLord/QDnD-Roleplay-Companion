import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

class FC5CompendiumIdentityService {
  static String fingerprintXml(String xmlContent) {
    final normalized = _normalizeXml(xmlContent);
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String _normalizeXml(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      return _normalizeNode(document.rootElement);
    } catch (_) {
      return xmlContent.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  static String _normalizeNode(XmlNode node) {
    if (node is XmlElement) {
      final attributes = node.attributes.toList()
        ..sort((a, b) => a.name.local.compareTo(b.name.local));
      final attrText = attributes
          .map((attr) => '${attr.name.local}=${_collapse(attr.value)}')
          .join('|');
      final children = node.children
          .where((child) =>
              child is XmlElement || child is XmlText || child is XmlCDATA)
          .map(_normalizeNode)
          .where((value) => value.isNotEmpty)
          .join('');
      return '<${node.name.local}|$attrText>$children</${node.name.local}>';
    }

    if (node is XmlText || node is XmlCDATA) {
      return _collapse(node.value ?? '');
    }

    return '';
  }

  static String _collapse(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
