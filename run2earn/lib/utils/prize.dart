Map<String, double> getPrize(int players) {
  if (players < 2) {
    return {
      "platform": 1.0, // nobody wins
    };
  }

  if (players == 2) {
    return {
      "first": 0.90,
      "platform": 0.10,
    };
  }

  if (players == 3) {
    return {
      "first": 0.70,
      "second": 0.20,
      "platform": 0.10,
    };
  }

  return {
    "first": 0.70,
    "second": 0.20,
    "third": 0.05,
    "platform": 0.05,
  };
}
