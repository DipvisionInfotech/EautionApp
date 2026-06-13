class AuctionItem {
  final String id;
  final String title;
  final String image;
  final String startTime;
  final String endTime;
  final String quantity;
  final String category;
  final String description;

  AuctionItem({
    required this.id,
    required this.title,
    required this.image,
    required this.startTime,
    required this.endTime,
    required this.quantity,
    required this.category,
    this.description = 'No description available.',
  });
}

class ClassifiedItem {
  final String id;
  final String title;
  final String image;
  final String quantity;
  final String price;
  final String location;
  final String description;

  ClassifiedItem({
    required this.id,
    required this.title,
    required this.image,
    required this.quantity,
    required this.price,
    required this.location,
    this.description = 'No description available.',
  });
}
