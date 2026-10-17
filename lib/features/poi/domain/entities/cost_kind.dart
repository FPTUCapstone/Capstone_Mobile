/// How a place's estimated cost should be read (Review 2, D1). The backend
/// derives it from the category: restaurants are an average spend, everything
/// else an admission ticket.
enum CostKind { admissionTicket, averageSpend }
