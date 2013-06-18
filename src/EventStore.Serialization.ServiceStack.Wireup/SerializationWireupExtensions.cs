namespace EventStore
{
	using Serialization;
    using EventStore.Serialization.ServiceStack;

	public static class WireupExtensions
	{
		public static SerializationWireup UsingServiceStackJsonSerialization(this PersistenceWireup wireup)
		{
			return wireup.UsingCustomSerialization(new ServiceStackSerializer());
		}

	}
}