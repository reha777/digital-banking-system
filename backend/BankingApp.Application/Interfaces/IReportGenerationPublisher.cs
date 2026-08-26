using BankingApp.Application.Messaging;
namespace BankingApp.Application.Interfaces;
public interface IReportGenerationPublisher { Task PublishAsync(ReportGenerationRequested message, CancellationToken cancellationToken = default); }
