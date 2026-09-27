type SectionHeadProps = {
  index: string;
  label: string;
  title: string;
  copy?: string;
};

export default function SectionHead({
  index,
  label,
  title,
  copy,
}: SectionHeadProps) {
  return (
    <div className="section-head">
      <p className="eyebrow">
        {index} / {label}
      </p>
      <div>
        <h2 className="type-h1">{title}</h2>
        {copy ? <p className="section-copy mt-4">{copy}</p> : null}
      </div>
    </div>
  );
}
