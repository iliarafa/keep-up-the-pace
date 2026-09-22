import { createFileRoute } from "@tanstack/react-router";
import { SetupView } from "@/components/setup-view";
import { WalkView } from "@/components/walk-view";
import { usePaceApp } from "@/hooks/use-pace-app";

export const Route = createFileRoute("/")({ component: Home });

function Home() {
  const app = usePaceApp();

  if ((app.phase === "walk" || app.phase === "arrived") && app.session && app.metrics) {
    return (
      <WalkView
        session={app.session}
        metrics={app.metrics}
        units={app.units}
        phase={app.phase === "arrived" ? "arrived" : "walk"}
        onEnd={app.endSession}
      />
    );
  }

  return (
    <SetupView
      units={app.units}
      setUnits={app.setUnits}
      destination={app.destination}
      origin={app.origin}
      geoStatus={app.geo.status}
      geoError={app.geo.error}
      requestGps={app.geo.start}
      arriveBy={app.arriveBy}
      arriveByInput={app.arriveByInput}
      setArriveByInput={app.setArriveByInput}
      bumpArriveBy={app.bumpArriveBy}
      chooseDestination={app.chooseDestination}
      recent={app.recent}
      planMeters={app.planMeters}
      canStart={app.canStart}
      onStart={app.startWalking}
      onDemo={app.startDemo}
    />
  );
}
