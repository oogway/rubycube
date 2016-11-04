ENV['RUBY_CUBE_TYPECHECK'] = "1"
#require_relative '../lib/cube'
require 'cube'
EmailNotifierT = Cube.trait do
  def notify
    puts "email sent to #{email}"
  end
  requires_interface Cube.interface {
    proto(:email) { String }
  }
end

AndroidNotifierT = Cube.trait do
  def notify
    puts "push notification sent to android device #{mobile_number}"  
  end

  requires_interface Cube.interface {
    proto(:mobile_number) { String }
  }
end

IOSNotifierT = Cube.trait do
  def notify
    puts "push notification sent to ios device #{mobile_number}"  
  end

  requires_interface Cube.interface {
    proto(:mobile_number) { String }
  }
end

CombinedNotifierT = Cube.trait do
  def notify
    mobile_notify
    email_notify
  end
  requires_interface Cube.interface {
    proto(:mobile_notify)
    proto(:email_notify)
  }
end

AndroidCombinedNotifier = Cube.trait.with_trait(AndroidNotifierT, rename: { notify: :mobile_notify })
                              .with_trait(EmailNotifierT, rename: { notify: :email_notify })
                              .with_trait(CombinedNotifierT)

IOSCombinedNotifier = Cube.trait.with_trait(IOSNotifierT, rename: { notify: :mobile_notify })
                          .with_trait(EmailNotifierT, rename: { notify: :email_notify })
                          .with_trait(CombinedNotifierT)

MobileEmailUser = Cube.interface {
  proto(:email) { String }
  proto(:mobile_number) { String }
}

Services = {
  android: AndroidCombinedNotifier.wrap(MobileEmailUser),
  ios: IOSCombinedNotifier.wrap(MobileEmailUser)
}
User = Struct.new(:email, :mobile_number, :type)
Cube.mark_interface!(User, MobileEmailUser)
CubeUser = Cube[User].as_interface(MobileEmailUser)

u1 = User.new('u1@foo.com', '1234567890', :android)
u2 = User.new('u2@foo.com', '1234567899', :ios)

[u1, u2].each do |u|
  Services[u.type].new(u).notify
end
