/// Represents a streaming channel.
class Channel {
  final String id;
  final String name;
  final String icon;
  final bool enabled;
  final int priority;
  final String? description;

  const Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.enabled,
    required this.priority,
    this.description,
  });

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String? ?? '📺',
        enabled: json['enabled'] as bool? ?? true,
        priority: json['priority'] as int? ?? 50,
        description: json['description'] as String?,
      );
}
