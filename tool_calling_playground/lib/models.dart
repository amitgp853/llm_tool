enum Cabin { economy, business }

const _defaultBags = 1;

/// A person on the flight.
class Passenger {
  const Passenger({
    required this.name,
    required this.age,
    this.bags = _defaultBags,
  });

  /// Full name as on the passport.
  final String name;
  final int age;

  /// Checked bags.
  final int bags;
}

/// One flight booking request.
class Booking {
  const Booking({
    required this.from,
    required this.to,
    required this.passengers,
    this.cabin = Cabin.economy,
  });

  /// Departure airport code, e.g. DEL.
  final String from;

  /// Arrival airport code, e.g. BOM.
  final String to;
  final List<Passenger> passengers;
  final Cabin cabin;
}
