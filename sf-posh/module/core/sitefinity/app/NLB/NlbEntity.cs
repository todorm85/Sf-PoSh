public class NlbEntity
{
    public NlbEntity()
    {

    }

    public NlbEntity(string nlbId, string projectId)
    {
        this.NlbId = nlbId;
        this.ProjectId = projectId;
    }

    public string ProjectId { get; set; }
    public string NlbId { get; set; }

    public override bool Equals(object obj)
    {
        var entity = (NlbEntity)obj;
        return this.NlbId == entity.NlbId && this.ProjectId == entity.ProjectId;
    }

    public override int GetHashCode()
    {
        return base.GetHashCode();
    }
}