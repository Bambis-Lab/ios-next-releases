import SwiftUI

struct OwnerProjectsView: View {
    let model: AdminControlModel
    let capabilities: OwnerCapabilityRegistry

    var body: some View {
        OwnerPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.pageSpacing) {
                HStack(spacing: 12) {
                    OwnerMetricView(title: "Projekte", value: "\(projectCount)", symbol: "folder.fill")
                    OwnerMetricView(title: "Offene Tickets", value: "\(model.ownerOpenTicketCount)", symbol: "ticket.fill", tint: model.ownerOpenTicketCount > 0 ? .orange : .green)
                }

                if !model.jobsV2.isEmpty {
                    HStack(spacing: 12) {
                        OwnerMetricView(title: "Jobs", value: "\(model.jobsV2.count)", symbol: "gearshape.2.fill")
                        OwnerMetricView(title: "Aktiv", value: "\(activeJobCount)", symbol: "play.circle.fill", tint: activeJobCount > 0 ? .blue : .green)
                    }
                }

                if capabilities.supports(.tickets) {
                    NavigationLink {
                        OwnerTicketInboxView(model: model)
                    } label: {
                        OwnerStatusRow(
                            title: "Tickets",
                            detail: "Anfragen lesen, beantworten und gezielt dispatchen",
                            symbol: "ticket.fill",
                            value: "\(model.ownerOpenTicketCount) offen",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                }

                IOSNextSectionHeader(title: "Projekte", subtitle: "Kanonische Repository-Zuordnung · Dispatch, Jobs und CI", symbol: "folder.fill")
                if !model.projectsV2.isEmpty {
                    ForEach(model.projectsV2) { project in
                        NavigationLink {
                            OwnerProjectDetailView(project: project, jobs: model.jobsV2.filter { $0.projectID == project.id })
                        } label: {
                            OwnerStatusRow(
                                title: project.title,
                                detail: ProjectRegistry.canonicalRepository(for: project) ?? "Kein Repository gemeldet",
                                symbol: "folder.fill",
                                value: projectValue(project),
                                tint: projectTint(project)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else if model.projectRoutes.isEmpty {
                    OwnerCapabilityUnavailableView(
                        title: "Projekt-Routen",
                        detail: capabilities.supports(.projects) ? "Noch keine Projekt-Routen geladen." : "Projekt-Routen werden vom aktuellen Backend nicht bereitgestellt."
                    )
                } else {
                    ForEach(model.projectRoutes) { route in
                        NavigationLink {
                            OwnerLegacyProjectDetailView(route: route)
                        } label: {
                            OwnerStatusRow(
                                title: route.title,
                                detail: ProjectRegistry.canonicalRepository(for: route) ?? "Kein Repository gemeldet",
                                symbol: "folder.fill",
                                value: "Öffnen"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Projekte")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refreshStatusV2() }
    }

    private var projectCount: Int {
        model.projectsV2.isEmpty ? model.projectRoutes.count : model.projectsV2.count
    }

    private var activeJobCount: Int {
        model.jobsV2.filter { !["completed", "resolved", "failed"].contains($0.state) }.count
    }

    private func projectValue(_ project: AdminProjectStatusV2) -> String {
        if project.activeJobs > 0 { return "\(project.activeJobs) aktiv" }
        guard let ci = project.ci else { return "CI nicht verfügbar" }
        switch ci.status {
        case "repository_missing": return "Kein Repository"
        case "adapter_not_configured": return "CI nicht eingerichtet"
        case "queued": return "CI wartet"
        case "in_progress": return "CI läuft"
        case "success": return "CI grün"
        case "failure": return "CI fehlgeschlagen"
        case "cancelled": return "CI abgebrochen"
        case "no_runs": return "Keine CI-Läufe"
        case "unavailable": return "CI nicht erreichbar"
        default:
            if let conclusion = ci.conclusion { return "CI \(conclusion.localizedCapitalized)" }
            return "CI Status unbekannt"
        }
    }

    private func projectTint(_ project: AdminProjectStatusV2) -> Color {
        if project.activeJobs > 0 { return .blue }
        switch project.ci?.status {
        case "success": return .green
        case "in_progress", "queued": return .blue
        case "failure": return .red
        case "cancelled", "unavailable": return .orange
        case "repository_missing", "adapter_not_configured", "no_runs", nil: return .secondary
        default: return .secondary
        }
    }
}

struct OwnerProjectDetailView: View {
    let project: AdminProjectStatusV2
    let jobs: [AdminJobStatusV2]

    var body: some View {
        OwnerPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
                OwnerStatusRow(title: project.title, detail: "Dispatch-Ziel", symbol: "folder.fill", value: project.id)

                if let repository = ProjectRegistry.canonicalRepository(for: project) {
                    OwnerStatusRow(
                        title: "Repository",
                        detail: ProjectRegistry.repositoryMismatch(for: project)
                            ? "Kanonische Zuordnung · Legacy-Mapping korrigiert"
                            : "Kanonische Zuordnung",
                        symbol: "chevron.left.forwardslash.chevron.right",
                        value: repository,
                        tint: .indigo
                    )
                } else {
                    OwnerCapabilityUnavailableView(title: "Repository", detail: "Für dieses Projekt ist kein Repository hinterlegt.")
                }

                OwnerStatusRow(title: "Dispatches", detail: "Persistente Owner-Freigaben", symbol: "paperplane.fill", value: "\(project.dispatchCount)")
                OwnerStatusRow(title: "Aktive Jobs", detail: "Nicht abgeschlossene Dispatch-Vorgänge", symbol: "gearshape.2.fill", value: "\(project.activeJobs)", tint: project.activeJobs > 0 ? .blue : .green)

                if let ci = project.ci {
                    OwnerStatusRow(
                        title: "CI",
                        detail: ci.workflow ?? ci.error ?? ciDetail(ci.status),
                        symbol: ciSymbol(ci.status),
                        value: ciTitle(ci.status),
                        tint: ciTint(ci.status)
                    )
                    if let sha = ci.headSHA {
                        OwnerStatusRow(title: "CI Commit", detail: "Head SHA", symbol: "number", value: String(sha.prefix(8)))
                    }
                } else {
                    OwnerCapabilityUnavailableView(title: "CI", detail: "CI-Status wurde vom Backend nicht geliefert.")
                }

                IOSNextSectionHeader(title: "Letzte Jobs", subtitle: nil, symbol: "clock.arrow.circlepath")
                if jobs.isEmpty {
                    OwnerStatusRow(title: "Keine Jobs", detail: "Für dieses Projekt liegt noch kein Dispatch vor.", symbol: "checkmark.circle", value: "0")
                } else {
                    ForEach(Array(jobs.prefix(20))) { job in
                        OwnerStatusRow(
                            title: job.ticketID,
                            detail: "Freigegeben von \(job.approvedBy)",
                            symbol: "paperplane.fill",
                            value: job.state.replacingOccurrences(of: "_", with: " ").localizedCapitalized,
                            tint: job.state == "failed" ? .red : .indigo
                        )
                    }
                }
            }
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ciTitle(_ state: String?) -> String {
        switch state {
        case "repository_missing": "Kein Repository"
        case "adapter_not_configured": "Nicht eingerichtet"
        case "queued": "Wartet"
        case "in_progress": "Läuft"
        case "success": "Grün"
        case "failure": "Fehlgeschlagen"
        case "cancelled": "Abgebrochen"
        case "no_runs": "Keine Läufe"
        case "unavailable": "Nicht erreichbar"
        default: "Unbekannt"
        }
    }

    private func ciDetail(_ state: String?) -> String {
        switch state {
        case "repository_missing": "Ohne Repository kann kein CI-Status abgefragt werden."
        case "adapter_not_configured": "GitHub-CI ist im Owner Backend noch nicht eingerichtet."
        case "no_runs": "Für dieses Repository wurde noch kein GitHub-Actions-Lauf gemeldet."
        case "unavailable": "GitHub-CI konnte momentan nicht abgefragt werden."
        default: "Letzter GitHub Actions Lauf"
        }
    }

    private func ciSymbol(_ state: String?) -> String {
        switch state {
        case "success": "checkmark.circle.fill"
        case "failure": "xmark.circle.fill"
        case "queued": "clock.fill"
        case "in_progress": "play.circle.fill"
        case "unavailable": "wifi.exclamationmark"
        default: "hammer.fill"
        }
    }

    private func ciTint(_ state: String?) -> Color {
        switch state {
        case "success": .green
        case "queued", "in_progress": .blue
        case "failure": .red
        case "cancelled", "unavailable": .orange
        default: .secondary
        }
    }
}

struct OwnerLegacyProjectDetailView: View {
    let route: ProjectRoute

    var body: some View {
        OwnerPage {
            VStack(alignment: .leading, spacing: IOSNextLayout.sectionSpacing) {
                OwnerStatusRow(title: route.title, detail: "Dispatch-Ziel", symbol: "folder.fill", value: route.id)
                if let repository = ProjectRegistry.canonicalRepository(for: route) {
                    OwnerStatusRow(title: "Repository", detail: "Kanonische Zuordnung", symbol: "chevron.left.forwardslash.chevron.right", value: repository, tint: .indigo)
                }
                OwnerCapabilityUnavailableView(title: "Job-Verlauf", detail: "Owner API v2 ergänzt Job- und CI-Status ohne Änderung der Hauptnavigation.")
            }
        }
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
