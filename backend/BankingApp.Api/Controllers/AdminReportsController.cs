using BankingApp.Application.Interfaces;
using BankingApp.Application.Reports;
using BankingApp.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace BankingApp.Api.Controllers;
[ApiController, Authorize(Roles = AppRoles.Admin), Route("api/admin/reports")]
public sealed class AdminReportsController(IAdminReportService service) : ControllerBase
{
    [HttpPost("transactions")] public async Task<ActionResult<ReportJobResponse>> Transactions(TransactionReportRequest request, CancellationToken token) { var job = await service.RequestTransactionAsync(request, token); return AcceptedAtAction(nameof(Get), new { id = job.Id }, job); }
    [HttpPost("loans")] public async Task<ActionResult<ReportJobResponse>> Loans(LoanPortfolioReportRequest request, CancellationToken token) { var job = await service.RequestLoanAsync(request, token); return AcceptedAtAction(nameof(Get), new { id = job.Id }, job); }
    [HttpGet("{id:guid}")] public async Task<ActionResult<ReportJobResponse>> Get(Guid id, CancellationToken token) => Ok(await service.GetAsync(id, token));
    [HttpGet] public async Task<IActionResult> List([FromQuery] ReportJobQuery query, CancellationToken token) => Ok(await service.ListAsync(query, token));
    [HttpGet("{id:guid}/download")] public async Task<IActionResult> Download(Guid id, CancellationToken token) { var file = await service.DownloadAsync(id, token); return File(file.Content, "application/pdf", file.FileName); }
}
