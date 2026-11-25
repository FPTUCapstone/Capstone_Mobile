typedef CommercialOption = ({int id, String name, num priceAmount});
typedef CommercialSlot = ({DateTime startsAt, int remainingQuantity});
typedef CommercialBookingRequest = ({
  int serviceId,
  DateTime startsAt,
  int quantity,
  String contactName,
  String contactPhone,
  String contactEmail,
  String specialRequest,
  int? itineraryId,
});
typedef CommercialBookingReceipt = ({
  String requestCode,
  String status,
  num estimatedAmount,
});

abstract interface class CommercialBookingRepository {
  Future<List<CommercialOption>> options(int poiId);
  Future<List<CommercialSlot>> availability(int serviceId);
  Future<CommercialBookingReceipt> submit(
    CommercialBookingRequest request,
    String key,
  );
}
