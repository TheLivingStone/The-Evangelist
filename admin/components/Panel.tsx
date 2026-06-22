// A titled section container ("chart card"). Used to frame every chart/table.

export default function Panel({
  title,
  subtitle,
  right,
  children,
  span,
}: {
  title?: string;
  subtitle?: string;
  right?: React.ReactNode;
  children: React.ReactNode;
  span?: number; // grid column span within .panels
}) {
  return (
    <section className="panel" style={span ? { gridColumn: `span ${span}` } : undefined}>
      {(title || right) && (
        <div className="panel-head">
          <div>
            {title ? <h3 className="panel-title">{title}</h3> : null}
            {subtitle ? <p className="panel-sub">{subtitle}</p> : null}
          </div>
          {right ? <div className="panel-right">{right}</div> : null}
        </div>
      )}
      {children}
    </section>
  );
}
